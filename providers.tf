provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "microk8s"
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "microk8s"
  }
}

provider "authentik" {
  url   = "http://${var.base_ip}:${var.app_ports["authentik"]}"
  token = random_password.all["bootstrap_token"].result
}

provider "vault" {
  address = "http://${var.base_ip}:${var.app_ports["vault"]}"
  # token   = random_password.all["vault_root"].result
}

provider "gitea" {
  alias    = "gitea"
  base_url = "http://${var.base_ip}:${var.app_ports["gitea"]}"
  username = "gitea-admin"
  password = random_password.all["gitea_admin"].result
  insecure = true
}
