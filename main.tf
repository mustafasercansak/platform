module "authentik" {
  source             = "./modules/authentik"
  namespace          = "authentik"
  node_port          = 30900
  secret_key         = local.pw["secret_key"]
  pg_pass            = local.pw["pg_pass"]
  bootstrap_password = local.pw["bootstrap_password"]
  bootstrap_token    = local.pw["bootstrap_token"]
  base_ip            = var.base_ip
  app_ports          = var.app_ports
}

module "vault" {
  source              = "./modules/vault"
  base_ip             = var.base_ip
  node_port           = var.app_ports["vault"]
  node_port_ui        = var.app_ports["vault_ui"]
  authentik_port      = var.app_ports["authentik"]
  vault_root_token    = local.pw["vault_root"]
  vault_client_secret = authentik_provider_oauth2.apps["vault"].client_secret
}

module "gitea" {
  source         = "./modules/gitea"
  base_ip        = var.base_ip
  node_port      = var.app_ports["gitea"]
  pg_pass        = local.pw["gitea_admin"]
  admin_pass     = local.pw["gitea_admin"]
  authentik_port = var.app_ports["authentik"]

  oidc = {
    client_id     = authentik_provider_oauth2.apps["gitea"].client_id
    client_secret = authentik_provider_oauth2.apps["gitea"].client_secret
  }
}
