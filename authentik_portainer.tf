# Authentik'ten paylaşılan flow ve sertifika verileri
# Bu data source'lar authentik_portainer.tf, authentik_grafana.tf vb. tüm dosyalardan kullanılabilir
data "authentik_flow" "default-authorization-flow" {
  slug       = "default-provider-authorization-explicit-consent"
  depends_on = [terraform_data.authentik_deploy]
}

data "authentik_flow" "default-invalidation-flow" {
  slug       = "default-invalidation-flow"
  depends_on = [terraform_data.authentik_deploy]
}

data "authentik_certificate_key_pair" "generated" {
  name       = "authentik Self-signed Certificate"
  depends_on = [terraform_data.authentik_deploy]
}

# --- Portainer OIDC entegrasyonu ---

resource "authentik_provider_oauth2" "portainer" {
  name               = "Portainer"
  client_id          = "portainer"
  client_type        = "confidential"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = var.portainer_url
    }
  ]
  signing_key = data.authentik_certificate_key_pair.generated.id
}

resource "authentik_application" "portainer" {
  name              = "Portainer"
  slug              = "portainer"
  protocol_provider = authentik_provider_oauth2.portainer.id
}

# Sadece portainer-admins grubundaki kullanıcılar erişebilir
resource "authentik_policy_binding" "portainer_admins" {
  target = authentik_application.portainer.uuid
  group  = authentik_group.groups["portainer-admins"].id
  order  = 0
}

output "portainer_oidc" {
  value = {
    client_id     = authentik_provider_oauth2.portainer.client_id
    client_secret = authentik_provider_oauth2.portainer.client_secret
    discovery_url = "http://${var.remote_host}:${local.authentik_http_port}/application/o/portainer/.well-known/openid-configuration"
  }
  sensitive = true
}
