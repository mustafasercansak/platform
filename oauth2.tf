locals {
  base = "http://${var.base_ip}"

  oauth2_apps = {
    gitea = {
      name          = "Gitea"
      redirect_uris = ["${local.base}:${var.app_ports["gitea"]}/user/oauth2/authentik/callback"]
      launch_url    = "${local.base}:${var.app_ports["gitea"]}"
    }
    grafana = {
      name          = "Grafana"
      redirect_uris = ["${local.base}:${var.app_ports["grafana"]}/login/generic_oauth"]
      launch_url    = "${local.base}:${var.app_ports["grafana"]}"
    }
    vault = {
      name          = "Vault"
      redirect_uris = ["${local.base}:${var.app_ports["vault"]}/ui/vault/auth/oidc/oidc/callback"]
      launch_url    = "${local.base}:${var.app_ports["vault"]}"
    }
    wikijs = {
      name          = "Wiki.js"
      redirect_uris = ["${local.base}:${var.app_ports["wikijs"]}/login/callback"]
      launch_url    = "${local.base}:${var.app_ports["wikijs"]}"
    }
    portainer = {
      name          = "Portainer"
      redirect_uris = ["${local.base}:${var.app_ports["portainer"]}/"]
      launch_url    = "${local.base}:${var.app_ports["portainer"]}"
    }
    traefik = {
      name          = "Traefik"
      redirect_uris = ["${local.base}:${var.app_ports["traefik"]}/callback"]
      launch_url    = "${local.base}:${var.app_ports["traefik"]}"
    }
  }
}

data "authentik_flow" "default_authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_invalidation" {
  slug = "default-provider-invalidation-flow"
}

resource "authentik_provider_oauth2" "apps" {
  for_each = local.oauth2_apps

  name               = each.value.name
  client_id          = each.key
  authorization_flow = data.authentik_flow.default_authorization.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id

  allowed_redirect_uris = [
    for uri in each.value.redirect_uris : {
      matching_mode = "strict"
      url           = uri
    }
  ]

  depends_on = [module.authentik]
}

resource "authentik_application" "apps" {
  for_each = local.oauth2_apps

  name              = each.value.name
  slug              = each.key
  protocol_provider = authentik_provider_oauth2.apps[each.key].id
  meta_launch_url   = each.value.launch_url

  depends_on = [module.authentik]
}
