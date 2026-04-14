locals {
  ssh_connection = {
    type        = "ssh"
    user        = var.remote_user
    host        = var.remote_host
    private_key = file(var.ssh_private_key_path)
  }
}

resource "terraform_data" "nuke_authentik" {
  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    private_key = local.ssh_connection.private_key
  }

  triggers_replace = [timestamp()]

  provisioner "remote-exec" {
    inline = [
      "echo '⚠️ Authentik veritabanı temizliği başlıyor...'",
      "if [ -d \"${var.authentik_app_path}\" ]; then",
      "  cd ${var.authentik_app_path}",
      "  if [ -f \"compose.yml\" ]; then",
      "    echo '[1/2] Containerlar durduruluyor ve Volumelar siliniyor...'",
      "    sudo docker-compose down -v",
      "  else",
      "    echo '❌ compose.yml bulunamadı, sadece manuel temizlik yapılacak.'",
      "  fi",
      "  echo '[2/2] Bind mount verileri temizleniyor... [data klasörü]'",
      "  sudo rm -rf data/*",
      "  echo '✅ Temizlik tamamlandı. Imajlar korundu.'",
      "else",
      "  echo '❌ ${var.authentik_app_path} dizini bulunamadı!'",
      "fi"
    ]
  }
}
