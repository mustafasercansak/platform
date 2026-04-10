locals {
  portainer_app = "portainer"
}

resource "terraform_data" "portainer_deploy" {
  # Port değişirse yeniden deploy et
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
      "sudo mkdir -p /opt/${local.portainer_app}/data",
      "sudo chown -R ${var.remote_user}:${var.remote_user} /opt/${local.portainer_app}",
      "sudo chmod 755 /opt/${local.portainer_app}",
    ]
  }

  provisioner "file" {
    content     = <<-EOT
      HTTP_PORT=${var.portainer_http_port}
      HTTPS_PORT=${var.portainer_https_port}
    EOT
    destination = "/tmp/.portainer.env"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/.portainer.env /opt/${local.portainer_app}/.env",
      "sudo chown ${var.remote_user}:${var.remote_user} /opt/${local.portainer_app}/.env",
      "sudo chmod 600 /opt/${local.portainer_app}/.env",
    ]
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
          - "${var.portainer_http_port}:9000"
          - "${var.portainer_https_port}:9443"
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
          - /opt/portainer/data:/data
    EOT
    destination = "/tmp/.portainer.compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/.portainer.compose.yml /opt/${local.portainer_app}/compose.yml",
      "sudo chown ${var.remote_user}:${var.remote_user} /opt/${local.portainer_app}/compose.yml",
      "sudo chmod 600 /opt/${local.portainer_app}/compose.yml",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo docker-compose -f /opt/${local.portainer_app}/compose.yml up -d",
    ]
  }

  # Portainer kurulmadan önce Authentik ayakta olmalı
  depends_on = [terraform_data.authentik_deploy]
}
