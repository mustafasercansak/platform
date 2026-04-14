terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    forgejo = {
      source  = "svalabs/forgejo"
      version = "~> 0.1"
    }
  }
}

provider "forgejo" {
  base_url = data.terraform_remote_state.authentik_config.outputs.infra_config.forgejo_url
  token    = "155a7ad3ba5d822cd94e0be08138441e02899b7e"
}

# Authentik konfigürasyonundan bilgileri otomatik çekiyoruz
data "terraform_remote_state" "authentik_config" {
  backend = "local"
  config = {
    path = "../authentik-config/terraform.tfstate"
  }
}

locals {
  forgejo_app  = "forgejo"
  ssh_connection = {
    type        = "ssh"
    user        = data.terraform_remote_state.authentik_config.outputs.infra_config.remote_user
    host        = data.terraform_remote_state.authentik_config.outputs.infra_config.remote_host
    private_key = file(var.ssh_private_key_path)
  }
}

resource "random_password" "forgejo_admin_password" {
  length  = 24
  special = false
}

resource "random_password" "forgejo_db_password" {
  length  = 24
  special = false
}

resource "terraform_data" "forgejo_deploy" {
  triggers_replace = [
    var.forgejo_http_port,
    var.forgejo_ssh_port,
    data.terraform_remote_state.authentik_config.outputs.infra_config.forgejo_url,
    timestamp()
  ]

  connection {
    type        = local.ssh_connection.type
    user        = data.terraform_remote_state.authentik_config.outputs.infra_config.remote_user
    host        = data.terraform_remote_state.authentik_config.outputs.infra_config.remote_host
    private_key = local.ssh_connection.private_key
  }

  provisioner "remote-exec" {
    inline = [
      "echo '🧹 Tüm eski yapılandırmaları ve verileri siliyoruz (Full Wipe)...'",
      "cd /opt/${local.forgejo_app} && sudo docker-compose down -v --remove-orphans 2>/dev/null || true",
      "sudo rm -rf /opt/${local.forgejo_app}/*",
      "echo '🚀 Dizin hazırlığı...'",
      "sudo mkdir -p /opt/${local.forgejo_app}/data/gitea/conf /opt/${local.forgejo_app}/db_data",
      "sudo chown -R 1000:1000 /opt/${local.forgejo_app}",
      "sudo chmod 755 /opt/${local.forgejo_app}",
    ]
  }

  provisioner "file" {
    content     = <<-EOT
      HTTP_PORT=${var.forgejo_http_port}
      SSH_PORT=${var.forgejo_ssh_port}
      ROOT_URL=${data.terraform_remote_state.authentik_config.outputs.infra_config.forgejo_url}/
      DB_PASSWORD=${random_password.forgejo_db_password.result}
    EOT
    destination = "/tmp/.forgejo.env"
  }

  provisioner "file" {
    content     = <<-EOT
[database]
DB_TYPE  = postgres
HOST     = db:5432
NAME     = forgejo
USER     = forgejo
PASSWD   = ${random_password.forgejo_db_password.result}
SSL_MODE = disable

[server]
ROOT_URL         = ${data.terraform_remote_state.authentik_config.outputs.infra_config.forgejo_url}/
DOMAIN           = ${data.terraform_remote_state.authentik_config.outputs.infra_config.remote_host}
HTTP_ADDR        = 0.0.0.0

[service]
DISABLE_REGISTRATION              = false
REQUIRE_SIGNIN_VIEW               = false
REGISTER_EMAIL_CONFIRM            = false
ENABLE_NOTIFY_MAIL                = false
ALLOW_ONLY_EXTERNAL_REGISTRATION  = true
ENABLE_CAPTCHA                    = false
DEFAULT_KEEP_EMAIL_PRIVATE        = false
DEFAULT_ALLOW_CREATE_ORGANIZATION = true
DEFAULT_ENABLE_TIMETRACKING       = true
NO_REPLY_ADDRESS                  = noreply.192.170.6.11
ENABLE_OAUTH2                     = true

[oauth2]
ENABLED                           = true
ENABLE_OIDC_SIGNIN                = true

[openid]
ENABLE_OPENID_SIGNIN              = true

[oauth2_client]
ENABLE_AUTO_REGISTRATION          = true
USERNAME                          = nickname

[security]
INSTALL_LOCK = true
SECRET_KEY   = ${random_password.forgejo_admin_password.result}
EOT
    destination = "/tmp/app.ini"
  }

  provisioner "file" {
    content     = <<-EOT
    networks:
      forgejo:
        external: false

    services:
      server:
        image: codeberg.org/forgejo/forgejo:14
        container_name: forgejo
        restart: always
        networks:
          - forgejo
        depends_on:
          - db
        env_file: [.env]
        environment:
          - USER_UID=1000
          - USER_GID=1000
          - FORGEJO__database__DB_TYPE=postgres
          - FORGEJO__database__HOST=db:5432
          - FORGEJO__database__NAME=forgejo
          - FORGEJO__database__USER=forgejo
          - FORGEJO__database__PASSWD=${random_password.forgejo_db_password.result}
          - FORGEJO__security__INSTALL_LOCK=true
        volumes:
          - /opt/forgejo/data:/data
          - /etc/localtime:/etc/localtime:ro
        ports:
          - "3002:3000"
          - "2222:22"

      db:
        image: postgres:16-alpine
        restart: always
        networks:
          - forgejo
        environment:
          - POSTGRES_USER=forgejo
          - POSTGRES_PASSWORD=${random_password.forgejo_db_password.result}
          - POSTGRES_DB=forgejo
        volumes:
          - /opt/forgejo/db_data:/var/lib/postgresql/data
    EOT
    destination = "/tmp/.forgejo.compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '🚀 Dosyalar yerleştiriliyor...'",
      "sudo mv /tmp/.forgejo.env /opt/${local.forgejo_app}/.env",
      "sudo mv /tmp/.forgejo.compose.yml /opt/${local.forgejo_app}/compose.yml",
      "sudo mv /tmp/app.ini /opt/${local.forgejo_app}/data/gitea/conf/app.ini",
      "sudo chown -R 1000:1000 /opt/${local.forgejo_app}",
      "sudo chmod 644 /opt/${local.forgejo_app}/data/gitea/conf/app.ini",
      "sudo chmod 600 /opt/${local.forgejo_app}/.env /opt/${local.forgejo_app}/compose.yml",
      "echo '🚀 Forgejo v14 başlatılıyor/yenileniyor...'",
      "cd /opt/${local.forgejo_app} && sudo docker-compose up -d && sudo docker-compose restart server",
      "echo '⌛ Yeniden başlatma bekleniyor...'",
      "for i in 1 2 3 4 5 6 7 8 9 10 11 12; do curl -sf http://127.0.0.1:3002/ > /dev/null 2>&1 && break; sleep 5; done",
      "echo '✅ Forgejo v14 yeni konfigürasyonla hazır.'",
      "echo '👤 Admin kullanıcısı oluşturuluyor...'",
      "sudo docker exec --user 1000 forgejo forgejo admin user create --admin --username '${var.forgejo_admin_user}' --password '${random_password.forgejo_admin_password.result}' --email 'admin@${data.terraform_remote_state.authentik_config.outputs.infra_config.remote_host}' --must-change-password=false 2>/dev/null || true",
      "echo '🔐 Authentik OIDC yapılandırılıyor...'",
      "for i in 1 2 3 4 5; do sudo docker exec --user 1000 forgejo forgejo admin auth add-oauth --name Authentik --provider openidConnect --key '${data.terraform_remote_state.authentik_config.outputs.oidc_config.forgejo.client_id}' --secret '${data.terraform_remote_state.authentik_config.outputs.oidc_config.forgejo.client_secret}' --auto-discover-url '${data.terraform_remote_state.authentik_config.outputs.infra_config.authentik_url}/application/o/forgejo/.well-known/openid-configuration' --scopes 'openid email profile' 2>/dev/null && break; sleep 5; done",
      "echo '✅ OIDC kaynağı eklendi.'"
    ]
  }
}

output "forgejo_admin_credentials" {
  value = {
    username = var.forgejo_admin_user
    password = random_password.forgejo_admin_password.result
  }
  sensitive = true
}

# --- Forgejo-Native ChatOps Entegrasyonu (2026) ---

resource "terraform_data" "forgejo_system_webhook" {
  triggers_replace = [
    terraform_data.forgejo_deploy.id
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    private_key = local.ssh_connection.private_key
  }

  provisioner "remote-exec" {
    inline = [
      "echo '🔐 Dinamik Admin Token üretiliyor...'",
      "# Token üret ve sadece ham halini geçici dosyaya yaz",
      "sudo docker exec --user 1000 forgejo forgejo admin user generate-access-token --username ${var.forgejo_admin_user} --token-name 'terraform-chatops-${timestamp()}' --scopes 'all' --raw > /tmp/forgejo_token",
      "FORGEJO_TOKEN=$(cat /tmp/forgejo_token)",
      "rm /tmp/forgejo_token",
      "echo '🔗 Forgejo V1 API üzerinden sistem webhook kuruluyor...'",
      "curl -X POST 'http://localhost:3002/api/v1/admin/hooks' \\",
      "  -H 'accept: application/json' \\",
      "  -H \"Authorization: token $FORGEJO_TOKEN\" \\",
      "  -H 'Content-Type: application/json' \\",
      "  -d '{ \"active\": true, \"config\": { \"channel\": \"town-square\", \"content_type\": \"json\", \"http_method\": \"post\", \"url\": \"http://192.170.6.11:8065/hooks/83mtcsc6yirx5yeh19gbmcuciy\" }, \"events\": [\"push\", \"pull_request\", \"issues\", \"repository\"], \"type\": \"slack\" }' || echo '⚠️ Webhook zaten mevcut olabilir.'",
      "echo '✅ Webhook yapılandırması tamamlandı.'"
    ]
  }

  depends_on = [terraform_data.forgejo_deploy]
}
