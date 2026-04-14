resource "random_password" "n8n_db_password" {
  length  = 24
  special = false
}

resource "random_password" "n8n_encryption_key" {
  length  = 24
  special = false
}

resource "random_password" "n8n_admin_password" {
  length  = 16
  special = false # Avoid shell escaping issues for now, or use restricted set
}

locals {
  n8n_app = "n8n"
}

resource "terraform_data" "n8n_deploy" {
  triggers_replace = [
    var.remote_host,
    "v9"
  ]

  connection {
    type        = "ssh"
    user        = var.remote_user
    host        = var.remote_host
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/${local.n8n_app}/data /opt/${local.n8n_app}/db_data",
      "sudo chown -R 1000:1000 /opt/${local.n8n_app}"
    ]
  }

  provisioner "file" {
    content     = <<EOF
DB_PASSWORD=${random_password.n8n_db_password.result}
ENCRYPTION_KEY=${random_password.n8n_encryption_key.result}
EOF
    destination = "/opt/${local.n8n_app}/.env"
  }

  provisioner "file" {
    content     = <<EOF
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: always
    ports:
      - "${var.n8n_port}:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=db
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=$${DB_PASSWORD}
      - N8N_ENCRYPTION_KEY=$${ENCRYPTION_KEY}
      - N8N_SECURE_COOKIE=false
      - N8N_EDITOR_BASE_URL=http://${var.remote_host}:${var.n8n_port}/
      - WEBHOOK_URL=http://${var.remote_host}:${var.n8n_port}/
      - N8N_PERSONALIZATION_ENABLED=false
    volumes:
      - ./data:/home/node/.n8n
    networks:
      - n8n

  db:
    image: postgres:16-alpine
    container_name: n8n-db
    restart: always
    environment:
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=$${DB_PASSWORD}
      - POSTGRES_DB=n8n
    volumes:
      - ./db_data:/var/lib/postgresql/data
    networks:
      - n8n

networks:
  n8n:
    driver: bridge
EOF
    destination = "/opt/${local.n8n_app}/compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /opt/${local.n8n_app} && sudo docker-compose down -v || true",
      "cd /opt/${local.n8n_app} && sudo docker-compose up -d",
      "echo '⌛ n8n başlatılıyor (API kurulumu için bekleniyor)...'",
      "for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do curl -sf http://127.0.0.1:5678/healthz > /dev/null 2>&1 && break; sleep 10; done",
      "sleep 15",
      "echo '👤 Admin kurulumu API üzerinden simüle ediliyor...'",
      "curl -X POST http://localhost:5678/rest/owner/setup -H 'Content-Type: application/json' -d '{\"email\":\"admin@n8n.local\",\"firstName\":\"Admin\",\"lastName\":\"User\",\"password\":\"${random_password.n8n_admin_password.result}\"}' || echo '⚠️ Manuel müdahale gerekebilir veya kurulum zaten tamamlanmış.'",
      "echo '✅ n8n hazır! http://${var.remote_host}:${var.n8n_port} adresinden erişebilirsiniz.'"
    ]
  }
}

output "n8n_admin_email" {
  value = "admin@n8n.local"
}

output "n8n_admin_password" {
  value     = random_password.n8n_admin_password.result
  sensitive = true
}
