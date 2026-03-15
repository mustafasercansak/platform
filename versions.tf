terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.12.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.8.0"
    }
    gitea = {
      source  = "go-gitea/gitea"
      version = "~> 0.7.0"
    }
  }
}
