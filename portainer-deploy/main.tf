terraform {
  required_providers {
    portainer = {
      source  = "portainer/portainer"
      version = "~> 1.28.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Authentik konfigürasyonundan bilgileri otomatik çekiyoruz
data "terraform_remote_state" "authentik_config" {
  backend = "local"
  config = {
    path = "../authentik-config/terraform.tfstate"
  }
}

locals {
  ssh_connection = {
    type        = "ssh"
    user        = data.terraform_remote_state.authentik_config.outputs.infra_config.remote_user
    host        = data.terraform_remote_state.authentik_config.outputs.infra_config.remote_host
    private_key = file(var.ssh_private_key_path)
  }
}

# --- Credentials ---

resource "random_password" "portainer_admin_password" {
  length  = 24
  special = false
}

output "portainer_admin_credentials" {
  value = {
    username = "admin"
    password = random_password.portainer_admin_password.result
  }
  sensitive = true
}

# --- Deployment ---

resource "terraform_data" "portainer_deploy" {
  triggers_replace = [
    var.portainer_http_port,
    var.portainer_https_port,
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
      "sudo mkdir -p ${var.portainer_app_path}/data",
      "sudo chown -R ${data.terraform_remote_state.authentik_config.outputs.infra_config.remote_user}:${data.terraform_remote_state.authentik_config.outputs.infra_config.remote_user} ${var.portainer_app_path}",
      "sudo chmod 755 ${var.portainer_app_path}",
    ]
  }

  provisioner "file" {
    content     = <<-EOT
      HTTP_PORT=${var.portainer_http_port}
      HTTPS_PORT=${var.portainer_https_port}
    EOT
    destination = "/tmp/.portainer.env"
  }

  provisioner "file" {
    content     = <<-EOT
    services:
      portainer:
        image: portainer/portainer-ce:lts
        container_name: portainer
        restart: unless-stopped
        env_file: [.env]
        ports:
          - "$${HTTP_PORT}:9000"
          - "$${HTTPS_PORT}:9443"
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
          - ${var.portainer_app_path}/data:/data
    EOT
    destination = "/tmp/.portainer.compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '🚀 Dosyalar yerleştiriliyor...'",
      "sudo mv /tmp/.portainer.env ${var.portainer_app_path}/.env",
      "sudo mv /tmp/.portainer.compose.yml ${var.portainer_app_path}/compose.yml",
      "sudo chown ${data.terraform_remote_state.authentik_config.outputs.infra_config.remote_user}:${data.terraform_remote_state.authentik_config.outputs.infra_config.remote_user} ${var.portainer_app_path}/.env ${var.portainer_app_path}/compose.yml",
      "sudo chmod 600 ${var.portainer_app_path}/.env ${var.portainer_app_path}/compose.yml",
      "echo '🚀 Portainer başlatılıyor...'",
      "cd ${var.portainer_app_path} && sudo docker-compose up -d",
      "echo '⌛ Portainer API hazır olması bekleniyor...'",
      "until curl -s http://localhost:9000/api/system/status > /dev/null; do sleep 2; done",
      "echo '✅ Portainer servisi hazır.'"
    ]
  }
}

# --- Initialization & Configuration ---

provider "portainer" {
  endpoint     = "http://${var.remote_host}:${var.portainer_http_port}"
  api_user     = "admin"
  api_password = random_password.portainer_admin_password.result
}

resource "portainer_user_admin" "init" {
  username = "admin"
  password = random_password.portainer_admin_password.result

  depends_on = [terraform_data.portainer_deploy]
}

# --- Post-Deployment Configuration (Portainer CE Fixer) ---

# Portainer CE sürümünde OIDC kullanıcılarını otomatik Admin yapma özelliği (BE özelliği) bulunmadığı için
# giriş yapan kullanıcıları API üzerinden otomatik olarak Admin rolüne (Role 1) yükseltiyoruz.
resource "terraform_data" "promote_oidc_users" {
  triggers_replace = [
    portainer_user_admin.init.id,
    timestamp() # Her apply'da yeni kullanıcıları kontrol etmesi için
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    private_key = local.ssh_connection.private_key
  }

  provisioner "remote-exec" {
    inline = [
      "echo '⚡ Portainer CE Yetki Tamirci çalışıyor...'",
      "TOKEN=$(curl -s -X POST -H 'Content-Type: application/json' -d '{\"Username\": \"admin\", \"Password\": \"${random_password.portainer_admin_password.result}\"}' http://localhost:${var.portainer_http_port}/api/auth | grep -oP '\"jwt\":\"\\K[^\"]+') && if [ -z \"$TOKEN\" ]; then echo '❌ Token alınamadı'; exit 1; fi",
      "echo '🔍 Standart kullanıcılar (Role 2) taranıyor...'",
      "ROLE2_IDS=$(curl -s -H \"Authorization: Bearer $TOKEN\" http://localhost:${var.portainer_http_port}/api/users | grep -oP '\\{\"Id\":\\K\\d+(?=,\"Username\":\"[^\"]+\",\"Role\":2)')",
      "if [ -z \"$ROLE2_IDS\" ]; then echo '✅ Terfi edilecek yeni kullanıcı bulunamadı.'; exit 0; fi",
      "for ID in $ROLE2_IDS; do",
      "  echo \"🚀 Kullanıcı (ID: $ID) Administrator rolüne yükseltiliyor...\"",
      "  curl -s -X PUT -H \"Authorization: Bearer $TOKEN\" -H \"Content-Type: application/json\" -d '{\"Role\": 1}' http://localhost:${var.portainer_http_port}/api/users/$ID > /dev/null",
      "done",
      "echo '✅ Tüm kullanıcılar Admin yapıldı.'"
    ]
  }

  depends_on = [portainer_user_admin.init]
}

# --- Authentik OIDC Yapılandırması (Native Provider) ---

resource "portainer_settings" "settings" {
  authentication_method = 3 # OAuth

  oauth_settings {
    client_id          = data.terraform_remote_state.authentik_config.outputs.oidc_config.portainer.client_id
    client_secret      = data.terraform_remote_state.authentik_config.outputs.oidc_config.portainer.client_secret
    authorization_uri  = "${data.terraform_remote_state.authentik_config.outputs.infra_config.authentik_url}/application/o/authorize/"
    access_token_uri   = "${data.terraform_remote_state.authentik_config.outputs.infra_config.authentik_url}/application/o/token/"
    resource_uri       = "${data.terraform_remote_state.authentik_config.outputs.infra_config.authentik_url}/application/o/userinfo/"
    redirect_uri       = "http://${data.terraform_remote_state.authentik_config.outputs.infra_config.remote_host}:${var.portainer_http_port}/"
    logout_uri         = "${data.terraform_remote_state.authentik_config.outputs.infra_config.authentik_url}/application/o/portainer/end-session/"
    user_identifier    = "preferred_username"
    scopes             = "openid profile email"
    sso                = true
    oauth_auto_create_users = true

    team_memberships {
      oauth_claim_name              = "groups"
      admin_auto_populate           = true
      admin_group_claims_regex_list = ["portainer-admins"]
    }
  }

  depends_on = [portainer_user_admin.init]
}
