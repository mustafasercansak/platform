locals {
  forgejo_app = "forgejo"
}

resource "random_password" "forgejo_admin_password" {
  length  = 24
  special = false
}

resource "terraform_data" "forgejo_deploy" {
  triggers_replace = [
    var.forgejo_http_port,
    var.forgejo_ssh_port,
    var.forgejo_url,
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    private_key = local.ssh_connection.private_key
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/${local.forgejo_app}/data",
      "sudo chown -R ${var.remote_user}:${var.remote_user} /opt/${local.forgejo_app}",
      "sudo chmod 755 /opt/${local.forgejo_app}",
    ]
  }

  provisioner "file" {
    content     = <<-EOT
      HTTP_PORT=${var.forgejo_http_port}
      SSH_PORT=${var.forgejo_ssh_port}
      ROOT_URL=${var.forgejo_url}/
    EOT
    destination = "/tmp/.forgejo.env"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/.forgejo.env /opt/${local.forgejo_app}/.env",
      "sudo chown ${var.remote_user}:${var.remote_user} /opt/${local.forgejo_app}/.env",
      "sudo chmod 600 /opt/${local.forgejo_app}/.env",
    ]
  }

  provisioner "file" {
    content     = <<-EOT
    services:
      forgejo:
        image: gitea/gitea:latest
        container_name: forgejo
        restart: unless-stopped
        env_file: [.env]
        environment:
          USER_UID: "1000"
          USER_GID: "1000"
          GITEA__database__DB_TYPE: sqlite3
          GITEA__server__HTTP_PORT: $${HTTP_PORT:-3000}
          GITEA__server__SSH_PORT: $${SSH_PORT:-2222}
          GITEA__server__ROOT_URL: $${ROOT_URL:-http://localhost:3000/}
          GITEA__server__DOMAIN: ${var.remote_host}
          GITEA__service__DISABLE_REGISTRATION: "true"
          GITEA__openid__ENABLE_OPENID_SIGNIN: "false"
          GITEA__oauth2_client__ENABLE_AUTO_REGISTRATION: "false"
        ports:
          - "${var.forgejo_http_port}:3000"
          - "${var.forgejo_ssh_port}:22"
        volumes:
          - /opt/forgejo/data:/data
    EOT
    destination = "/tmp/.forgejo.compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/.forgejo.compose.yml /opt/${local.forgejo_app}/compose.yml",
      "sudo chown ${var.remote_user}:${var.remote_user} /opt/${local.forgejo_app}/compose.yml",
      "sudo chmod 600 /opt/${local.forgejo_app}/compose.yml",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo docker rm -f forgejo 2>/dev/null || true",
      "sudo docker network rm forgejo_default 2>/dev/null || true",
      "sudo docker ps -q --filter publish=${var.forgejo_http_port} | xargs -r sudo docker rm -f 2>/dev/null || true",
      "sudo docker-compose -f /opt/${local.forgejo_app}/compose.yml up -d",
    ]
  }

  # Forgejo ayağa kalktıktan sonra admin kullanıcıyı oluştur
  provisioner "remote-exec" {
    inline = [
      # Hazır olana kadar bekle (max 60s)
      "for i in 1 2 3 4 5 6 7 8 9 10 11 12; do curl -sf http://127.0.0.1:${var.forgejo_http_port}/ > /dev/null 2>&1 && break; sleep 5; done",
      # Admin kullanıcı oluştur (zaten varsa hata vermez)
      "sudo docker exec forgejo gitea admin user create --admin --username '${var.forgejo_admin_user}' --password '${random_password.forgejo_admin_password.result}' --email 'admin@${var.remote_host}' --must-change-password=false 2>/dev/null || true",
    ]
  }

  depends_on = [terraform_data.authentik_deploy]
}

output "forgejo_admin" {
  value = {
    username = var.forgejo_admin_user
    password = random_password.forgejo_admin_password.result
    url      = var.forgejo_url
  }
  sensitive = true
}
