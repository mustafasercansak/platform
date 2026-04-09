locals {
  app = "authentik"
}

resource "random_password" "pg_pass" {
  length  = 36
  special = false
}

resource "random_password" "secret_key" {
  length  = 60
  special = false
}

resource "random_password" "bootstrap_password" {
  length  = 36
  special = false
}

output "authentik" {
  value = {
    pg_pass    = random_password.pg_pass.result
    secret_key = random_password.secret_key.result
    bootstrap_password = random_password.bootstrap_password.result
  }
  sensitive = true
}

resource "terraform_data" "create_directory" {
  triggers_replace = [
    timestamp()
  ]

  connection {
    type        = "ssh"
    user        = var.remote_user
    host        = var.remote_host
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      # Bash kontrolü: [ ! -d YOL ] -> Klasör dizin değilse (yoksa)
      "if [ ! -d /opt/${local.app} ]; then",
      "  echo 'Dizin bulunamadı, oluşturuluyor...'",
      "  sudo mkdir -p /opt/${local.app}",
      "  sudo chown ${var.remote_user}:${var.remote_user} /opt/${local.app}",
      "  sudo chmod 755 /opt/${local.app}",
      "else",
      "  echo 'Dizin zaten mevcut, işlem atlanıyor.'",
      "fi"
    ]
  }

  provisioner "file" {
    content     = <<-EOT
      PG_PASS=${bcrypt(random_password.pg_pass.result)}
      AUTHENTIK_SECRET_KEY=${bcrypt(random_password.bootstrap_password.result)} 
      AUTHENTIK_BOOTSTRAP_PASSWORD=${random_password.bootstrap_password.result}
    EOT
    destination = "/home/${var.remote_user}/.env.tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /home/${var.remote_user}/.env.tmp /opt/${local.app}/.env",
      "sudo chown ${var.remote_user}:${var.remote_user} /opt/${local.app}/.env",
      "sudo chmod 600 /opt/${local.app}/.env"
    ]
  }
}
