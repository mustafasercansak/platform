# Authentik konfigürasyonundan bilgileri otomatik çekiyoruz
data "terraform_remote_state" "authentik_config" {
  backend = "local"
  config = {
    path = "../authentik-config/terraform.tfstate"
  }
}

locals {
  app_name = "mattermost"
  ssh_connection = {
    type        = "ssh"
    user        = data.terraform_remote_state.authentik_config.outputs.infra_config.remote_user
    host        = data.terraform_remote_state.authentik_config.outputs.infra_config.remote_host
    private_key = file(var.ssh_private_key_path)
  }
}

resource "random_password" "mm_db_password" {
  length  = 24
  special = false
}

resource "terraform_data" "mattermost_deploy" {
  triggers_replace = [
    local.ssh_connection.host,
    timestamp()
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    private_key = local.ssh_connection.private_key
  }

  provisioner "file" {
    content     = <<EOF
DB_PASSWORD=${random_password.mm_db_password.result}
MM_CLIENT_ID=${data.terraform_remote_state.authentik_config.outputs.oidc_config.mattermost.client_id}
MM_CLIENT_SECRET=${data.terraform_remote_state.authentik_config.outputs.oidc_config.mattermost.client_secret}
EOF
    destination = "/tmp/mattermost_env"
  }

  provisioner "file" {
    content     = <<EOF
services:
  db:
    image: postgres:16-alpine
    container_name: mattermost-db
    restart: always
    environment:
      - POSTGRES_USER=mmuser
      - POSTGRES_PASSWORD=$${DB_PASSWORD}
      - POSTGRES_DB=mattermost
    volumes:
      - ./db_data:/var/lib/postgresql/data
    networks:
      - mattermost

  mattermost:
    image: mattermost/mattermost-enterprise-edition:latest
    container_name: mattermost
    restart: always
    ports:
      - "${var.mattermost_port}:8065"
    environment:
      - MM_SERVICESETTINGS_SITEURL=${data.terraform_remote_state.authentik_config.outputs.infra_config.mattermost_url}
      - MM_SERVICESETTINGS_ENABLESETUPWIZARD=false
      - MM_SERVICESETTINGS_ENABLEONBOARDINGFLOW=false
      - MM_SERVICESETTINGS_ENABLETUTORIAL=false
      - MM_SERVICESETTINGS_ENABLELOCALMODE=true
      - MM_SQLSETTINGS_DRIVERNAME=postgres
      - MM_SQLSETTINGS_DATASOURCE=postgres://mmuser:$${DB_PASSWORD}@db:5432/mattermost?sslmode=disable&connect_timeout=10
      - MM_BLEVESETTINGS_INDEXDIR=/mattermost/bleve-indexes
      # Team Settings
      - MM_TEAMSETTINGS_SITENAME=MSS Platform
      # Auth Restrictions (SSO Only)
      - MM_EMAILSETTINGS_ENABLESIGNUPWITHEMAIL=false
      - MM_EMAILSETTINGS_ENABLESIGNINWITHEMAIL=false
      - MM_EMAILSETTINGS_ENABLESIGNINWITHUSERNAME=false
      # SSO (GitLab) - Authentik
      - MM_GITLABSETTINGS_ENABLE=true
      - MM_GITLABSETTINGS_ID=$${MM_CLIENT_ID}
      - MM_GITLABSETTINGS_SECRET=$${MM_CLIENT_SECRET}
      - MM_GITLABSETTINGS_SCOPE=openid profile email gitlab
      - MM_GITLABSETTINGS_AUTHENDPOINT=${data.terraform_remote_state.authentik_config.outputs.infra_config.authentik_url}/application/o/authorize/
      - MM_GITLABSETTINGS_TOKENENDPOINT=${data.terraform_remote_state.authentik_config.outputs.infra_config.authentik_url}/application/o/token/
      - MM_GITLABSETTINGS_USERAPIENDPOINT=${data.terraform_remote_state.authentik_config.outputs.infra_config.authentik_url}/application/o/userinfo/
    volumes:
      - ./config:/mattermost/config
      - ./data:/mattermost/data
      - ./logs:/mattermost/logs
      - ./plugins:/mattermost/plugins
      - ./client/plugins:/mattermost/client/plugins
      - ./bleve-indexes:/mattermost/bleve-indexes
    depends_on:
      - db
    networks:
      - mattermost

networks:
  mattermost:
    driver: bridge
EOF
    destination = "/tmp/mattermost_compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '🧹 Dizin ve İzin hazırlığı...'",
      "sudo mkdir -p /opt/mattermost/config /opt/mattermost/data /opt/mattermost/logs /opt/mattermost/plugins /opt/mattermost/client/plugins /opt/mattermost/db_data",
      "sudo chown -R 2000:2000 /opt/mattermost",
      "sudo chown -R 999:999 /opt/mattermost/db_data",
      "echo '🚀 Dosyalar yerleştiriliyor...'",
      "sudo mv /tmp/mattermost_compose.yml /opt/mattermost/compose.yml",
      "sudo mv /tmp/mattermost_env /opt/mattermost/.env",
      "echo '🚀 Mattermost başlatılıyor/güncelleniyor...'",
      "cd /opt/mattermost && sudo docker-compose up -d",
      "echo '⏳ Mattermost sunucusunun ayağa kalkması bekleniyor (5dk limit)...'",
      "i=1; while [ $i -le 60 ]; do status=$(sudo docker inspect -f '{{.State.Health.Status}}' mattermost 2>/dev/null || echo 'unknown'); if [ \"$status\" = \"healthy\" ]; then echo \"✅ Sunucu sağlıklı.\"; break; fi; echo \"⏳ Bekleniyor... (Durum: $status)\"; i=$((i+1)); sleep 5; done",
      "echo '🏗️  Varsayılan takım kontrol ediliyor (MSS)...'",
      "sudo docker exec mattermost mmctl team create --name mss --display-name 'MSS Team' --email admin@mss.local --local || echo '⚠️ Takım zaten mevcut.'",
      "echo '🔗 Forgejo Webhook oluşturuluyor/güncelleniyor...'",
      "# Webhook zaten varsa hata vermesi için true ile devam et (idempotency)",
      "sudo docker exec mattermost mmctl webhook create-incoming --channel rzhky3mio7ns8n5etjamuq87jy --user spaqobwyojd53caiiu4j78o7hy --display-name 'Forgejo Bot' --description 'Forgejo Bildirimleri' --local || echo '⚠️ Webhook güncellendi veya oluşturulamadı.'",
      "echo '⚡ n8n Slash Command oluşturuluyor/güncelleniyor (/n8n)...'",
      "sudo docker exec mattermost mmctl command create 35gcdjt1d3f99cz9jgwzcijyua --title 'n8n ChatOps' --description 'n8n iş akışlarını tetikler' --trigger-word n8n --url 'http://192.170.6.11:5678/webhook/mattermost' --creator mmadmin --autocomplete --local || echo '⚠️ Komut güncellendi veya oluşturulamadı.'",
      "echo '✅ Mattermost ChatOps aktif! http://${data.terraform_remote_state.authentik_config.outputs.infra_config.remote_host}:8065 adresinden erişebilirsiniz.'"
    ]
  }
}
