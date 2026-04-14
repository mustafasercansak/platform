locals {
  ssh_connection = {
    type        = "ssh"
    user        = var.remote_user
    host        = var.remote_host
    private_key = file(var.ssh_private_key_path)
  }
}

resource "terraform_data" "portainer_cleanup" {
  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    private_key = local.ssh_connection.private_key
  }

  triggers_replace = [timestamp()]

  provisioner "remote-exec" {
    inline = [
      "echo '⚠️ Portainer temizliği başlıyor...'",
      "if [ -d \"${var.portainer_app_path}\" ]; then",
      "  cd ${var.portainer_app_path}",
      "  if [ -f \"compose.yml\" ]; then",
      "    echo '[1/2] Portainer konteynerları durduruluyor ve volumelar siliniyor...'",
      "    sudo docker-compose down -v",
      "  fi",
      "  echo '[2/2] Tüm Portainer dizini siliniyor... (${var.portainer_app_path})'",
      "  sudo rm -rf ${var.portainer_app_path}",
      "  echo '✅ Temizlik tamamlandı.'",
      "else",
      "  echo '❌ ${var.portainer_app_path} dizini bulunamadı!'",
      "fi"
    ]
  }
}
