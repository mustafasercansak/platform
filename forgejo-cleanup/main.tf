locals {
  ssh_connection = {
    type        = "ssh"
    user        = var.remote_user
    host        = var.remote_host
    private_key = file(var.ssh_private_key_path)
  }
}

resource "terraform_data" "forgejo_cleanup" {
  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    private_key = local.ssh_connection.private_key
  }

  triggers_replace = [timestamp()]

  provisioner "remote-exec" {
    inline = [
      "echo '⚠️ Forgejo temizliği başlıyor...'",
      "if [ -d \"${var.forgejo_app_path}\" ]; then",
      "  cd ${var.forgejo_app_path}",
      "  if [ -f \"compose.yml\" ] || [ -f \"docker-compose.yml\" ]; then",
      "    echo '[1/2] Forgejo konteynerları durduruluyor ve volumelar siliniyor...'",
      "    sudo docker-compose down -v 2>/dev/null || sudo docker rm -f forgejo 2>/dev/null || true",
      "  fi",
      "  echo '[2/2] Tüm Forgejo dizini siliniyor... (${var.forgejo_app_path})'",
      "  sudo rm -rf ${var.forgejo_app_path}",
      "  echo '✅ Forgejo temizliği tamamlandı.'",
      "else",
      "  echo '❌ ${var.forgejo_app_path} dizini bulunamadı!'",
      "fi"
    ]
  }
}
