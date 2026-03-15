resource "gitea_oauth2_application" "authentik" {
  name              = "authentik"
  provider_name     = "openidConnect"
  key               = authentik_provider_oauth2.apps["gitea"].client_id
  secret            = authentik_provider_oauth2.apps["gitea"].client_secret
  auto_discover_url = "http://${var.base_ip}:${var.app_ports["authentik"]}/application/o/gitea/.well-known/openid-configuration"
  redirect_uris     = ["http://${var.base_ip}:${var.app_ports["gitea"]}/user/oauth2/authentik/callback"]

  depends_on = [module.gitea]
}
