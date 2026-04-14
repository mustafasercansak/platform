# --- Portainer OIDC ---

resource "authentik_provider_oauth2" "portainer" {
  name      = "Portainer"
  client_id = "portainer"

  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = var.portainer_url
    }
  ]
  signing_key = data.authentik_certificate_key_pair.generated.id
  property_mappings = [
    for s in data.authentik_property_mapping_provider_scope.scopes : s.id
  ]
}

resource "authentik_application" "portainer" {
  name              = "Portainer"
  slug              = "portainer"
  protocol_provider = authentik_provider_oauth2.portainer.id
}

resource "authentik_policy_binding" "portainer_admins" {
  target = authentik_application.portainer.uuid
  group  = authentik_group.groups["portainer-admins"].id
  order  = 0
}

# --- Forgejo OIDC ---

resource "authentik_provider_oauth2" "forgejo" {
  name               = "Forgejo"
  client_id          = "forgejo"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "${var.forgejo_url}/user/oauth2/Authentik/callback"
    }
  ]
  signing_key = data.authentik_certificate_key_pair.generated.id
  property_mappings = [
    for s in data.authentik_property_mapping_provider_scope.scopes : s.id
  ]
}

resource "authentik_application" "forgejo" {
  name              = "Forgejo"
  slug              = "forgejo"
  protocol_provider = authentik_provider_oauth2.forgejo.id
}

resource "authentik_policy_binding" "forgejo_users" {
  target = authentik_application.forgejo.uuid
  group  = authentik_group.groups["forgejo-users"].id
  order  = 0
}

# --- n8n Proxy ---

resource "authentik_provider_proxy" "n8n" {
  name               = "n8n"
  internal_host      = "http://n8n:5678"
  external_host      = "http://192.170.6.11:5678"
  mode               = "forward_single"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
}

resource "authentik_application" "n8n" {
  name              = "n8n"
  slug              = "n8n"
  protocol_provider = authentik_provider_proxy.n8n.id
}

resource "authentik_policy_binding" "n8n_users" {
  target = authentik_application.n8n.uuid
  group  = authentik_group.groups["forgejo-users"].id # Reuse forgejo-users group for now
  order  = 0
}

# --- n8n Service Account ---

resource "authentik_user" "n8n_service_account" {
  username = "n8n-service-account"
  name     = "n8n Service Account"
  type     = "service_account"
}

resource "authentik_token" "n8n" {
  identifier   = "n8n-proxy-token"
  user         = authentik_user.n8n_service_account.id
  intent       = "api"
  retrieve_key = true
}

# --- Mattermost OIDC (GitLab SSO Compatibility) ---

resource "authentik_provider_oauth2" "mattermost" {
  name      = "Mattermost"
  client_id = "mattermost"

  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "http://${var.remote_host}:8065/signup/gitlab/complete"
    },
    {
      matching_mode = "strict"
      url           = "http://${var.remote_host}:8065/login/gitlab/complete"
    }
  ]
  signing_key = data.authentik_certificate_key_pair.generated.id
  property_mappings = concat(
    [for s in data.authentik_property_mapping_provider_scope.scopes : s.id],
    [authentik_property_mapping_provider_scope.gitlab.id]
  )
}

resource "authentik_application" "mattermost" {
  name              = "Mattermost"
  slug              = "mattermost"
  protocol_provider = authentik_provider_oauth2.mattermost.id
}

resource "authentik_policy_binding" "mattermost_users" {
  target = authentik_application.mattermost.uuid
  group  = authentik_group.groups["forgejo-users"].id # Reuse platform user group
  order  = 0
}

# --- n8n Outpost ---

resource "authentik_outpost" "n8n" {
  name               = "n8n-outpost"
  type               = "proxy"
  service_connection = null # Local outpost
  protocol_providers = [
    authentik_provider_proxy.n8n.id
  ]
}

# --- Çıktılar ---

output "oidc_config" {
  value = {
    portainer = {
      client_id     = authentik_provider_oauth2.portainer.client_id
      client_secret = authentik_provider_oauth2.portainer.client_secret
    }
    forgejo = {
      client_id     = authentik_provider_oauth2.forgejo.client_id
      client_secret = authentik_provider_oauth2.forgejo.client_secret
    }
    mattermost = {
      client_id     = authentik_provider_oauth2.mattermost.client_id
      client_secret = authentik_provider_oauth2.mattermost.client_secret
    }
  }
  sensitive = true
}

output "n8n_proxy_config" {
  value = {
    # Using the key from the managed token resource
    token = authentik_token.n8n.key
  }
  sensitive = true
}

# --- Shared Infrastructure Outputs ---

output "infra_config" {
  value = {
    remote_host          = var.remote_host
    remote_user          = "vys" # Default or from var if needed
    ssh_private_key_path = "~/.ssh/id_rsa"
    authentik_url        = var.authentik_url
    forgejo_url          = "http://192.170.6.11:3002"
    portainer_url        = var.portainer_url
    n8n_url              = "http://192.170.6.11:5678"
    mattermost_url       = "http://192.170.6.11:8065"
  }
}
