terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2024.12.0"
    }
  }
}

provider "authentik" {
  url   = "http://${var.remote_host}:9000"
  token = random_password.bootstrap_token.result
}

locals {
  ssh_connection = {
    type        = "ssh"
    user        = var.remote_user
    host        = var.remote_host
    private_key = file(var.ssh_private_key_path)
  }
}
