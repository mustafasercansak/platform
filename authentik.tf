locals {
  authentik_app        = "authentik"
  authentik_http_port  = 9000
  authentik_https_port = 9443
}

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

resource "terraform_data" "authentik_deploy" {
  # Şifreler veya portlar değişirse yeniden deploy et
  triggers_replace = [
    random_password.pg_pass.result,
    random_password.secret_key.result,
    local.authentik_http_port,
    local.authentik_https_port,
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    private_key = local.ssh_connection.private_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/${local.authentik_app}",
      "sudo chown ${var.remote_user}:${var.remote_user} /opt/${local.authentik_app}",
      "sudo chmod 755 /opt/${local.authentik_app}",
    ]
  }

  provisioner "file" {
    content     = <<-EOT
      PG_PASS=${random_password.pg_pass.result}
      AUTHENTIK_SECRET_KEY=${random_password.secret_key.result}
      AUTHENTIK_BOOTSTRAP_PASSWORD=${random_password.bootstrap_password.result}
      AUTHENTIK_BOOTSTRAP_TOKEN=${random_password.bootstrap_token.result}
      COMPOSE_PORT_HTTP=${local.authentik_http_port}
      COMPOSE_PORT_HTTPS=${local.authentik_https_port}
    EOT
    destination = "/tmp/.authentik.env"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/.authentik.env /opt/${local.authentik_app}/.env",
      "sudo chown ${var.remote_user}:${var.remote_user} /opt/${local.authentik_app}/.env",
      "sudo chmod 600 /opt/${local.authentik_app}/.env",
    ]
  }

  provisioner "file" {
    content     = <<-EOT
    # Authentik 2026.2.1 - No Redis Required (PostgreSQL handles tasks/cache)
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
      "sudo mv /tmp/.authentik.compose.yml /opt/${local.authentik_app}/compose.yml",
      "sudo chown ${var.remote_user}:${var.remote_user} /opt/${local.authentik_app}/compose.yml",
      "sudo chmod 600 /opt/${local.authentik_app}/compose.yml",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo docker-compose -f /opt/${local.authentik_app}/compose.yml up -d",
    ]
  }
}
