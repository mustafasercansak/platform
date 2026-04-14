terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

locals {
  authentik_app = "authentik"
  ssh_connection = {
    type        = "ssh"
    user        = var.remote_user
    host        = var.remote_host
    private_key = file(var.ssh_private_key_path)
  }
}

# Credentials
resource "random_password" "pg_pass" {
  length  = 36
  special = false
}

resource "random_password" "secret_key" {
  length  = 60
  special = false
}

resource "random_password" "bootstrap_token" {
  length  = 64
  special = false
}

resource "random_password" "bootstrap_password" {
  length  = 36
  special = false
}

output "authentik_credentials" {
  value = {
    pg_pass            = random_password.pg_pass.result
    secret_key         = random_password.secret_key.result
    bootstrap_password = random_password.bootstrap_password.result
    bootstrap_token    = random_password.bootstrap_token.result
  }
  sensitive = true
}

# Deployment
resource "terraform_data" "authentik_deploy" {
  triggers_replace = [
    random_password.pg_pass.result,
    random_password.secret_key.result,
    var.authentik_http_port,
    var.authentik_https_port,
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    private_key = local.ssh_connection.private_key
  }

  provisioner "remote-exec" {
    inline = [
      "echo '🚀 Dizin hazırlığı...'",
      "sudo mkdir -p ${var.authentik_app_path}",
      "sudo chown ${var.remote_user}:${var.remote_user} ${var.authentik_app_path}",
      "sudo chmod 755 ${var.authentik_app_path}",
    ]
  }

  provisioner "file" {
    content     = <<-EOT
      PG_PASS=${random_password.pg_pass.result}
      AUTHENTIK_SECRET_KEY=${random_password.secret_key.result}
      AUTHENTIK_BOOTSTRAP_PASSWORD=${random_password.bootstrap_password.result}
      AUTHENTIK_BOOTSTRAP_TOKEN=${random_password.bootstrap_token.result}
      COMPOSE_PORT_HTTP=${var.authentik_http_port}
      COMPOSE_PORT_HTTPS=${var.authentik_https_port}
    EOT
    destination = "/tmp/.authentik.env"
  }

  provisioner "file" {
    content     = <<-EOT
    services:
      postgresql:
        image: docker.io/library/postgres:16-alpine
        env_file: [.env]
        environment:
          POSTGRES_DB: $${PG_DB:-authentik}
          POSTGRES_USER: $${PG_USER:-authentik}
          POSTGRES_PASSWORD: $${PG_PASS:?database password required}
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
          start_period: 20s
          interval: 30s
          retries: 5
          timeout: 5s
        restart: unless-stopped
        volumes:
          - database:/var/lib/postgresql/data
      server:
        image: ghcr.io/goauthentik/server:2026.2.1
        command: server
        depends_on:
          postgresql:
            condition: service_healthy
        env_file: [.env]
        environment:
          AUTHENTIK_POSTGRESQL__HOST: postgresql
          AUTHENTIK_POSTGRESQL__NAME: $${PG_DB:-authentik}
          AUTHENTIK_POSTGRESQL__USER: $${PG_USER:-authentik}
          AUTHENTIK_POSTGRESQL__PASSWORD: $${PG_PASS}
          AUTHENTIK_SECRET_KEY: $${AUTHENTIK_SECRET_KEY:?secret key required}
          AUTHENTIK_BOOTSTRAP_PASSWORD: $${AUTHENTIK_BOOTSTRAP_PASSWORD}
          AUTHENTIK_BOOTSTRAP_TOKEN: $${AUTHENTIK_BOOTSTRAP_TOKEN}
        ports:
          - "$${COMPOSE_PORT_HTTP:-9000}:9000"
          - "$${COMPOSE_PORT_HTTPS:-9443}:9443"
        restart: unless-stopped
        shm_size: 512mb
        volumes:
          - ./data:/data
          - ./custom-templates:/templates
      worker:
        image: ghcr.io/goauthentik/server:2026.2.1
        command: worker
        depends_on:
          postgresql:
            condition: service_healthy
        env_file: [.env]
        environment:
          AUTHENTIK_POSTGRESQL__HOST: postgresql
          AUTHENTIK_POSTGRESQL__NAME: $${PG_DB:-authentik}
          AUTHENTIK_POSTGRESQL__USER: $${PG_USER:-authentik}
          AUTHENTIK_POSTGRESQL__PASSWORD: $${PG_PASS}
          AUTHENTIK_SECRET_KEY: $${AUTHENTIK_SECRET_KEY:?secret key required}
        restart: unless-stopped
        shm_size: 512mb
        user: root
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
          - ./data:/data
          - ./certs:/certs
          - ./custom-templates:/templates
    volumes:
      database:
        driver: local
    EOT
    destination = "/tmp/.authentik.compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '🚀 Dosyalar yerleştiriliyor...'",
      "sudo mv /tmp/.authentik.env ${var.authentik_app_path}/.env",
      "sudo mv /tmp/.authentik.compose.yml ${var.authentik_app_path}/compose.yml",
      "sudo chown ${var.remote_user}:${var.remote_user} ${var.authentik_app_path}/.env ${var.authentik_app_path}/compose.yml",
      "sudo chmod 600 ${var.authentik_app_path}/.env ${var.authentik_app_path}/compose.yml",
      "echo '🚀 Docker konteynerları başlatılıyor...'",
      "cd ${var.authentik_app_path} && sudo docker-compose up -d",
      "echo '✅ Kurulum tamamlandı! Authentik başlatıldı.'",
      "echo '🔗 Erişim: http://${var.remote_host}:${var.authentik_http_port}'"
    ]
  }
}
