# --- Forgejo OIDC entegrasyonu ---

resource "authentik_provider_oauth2" "forgejo" {
  name               = "Forgejo"
  client_id          = "forgejo"
  client_type        = "confidential"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "${var.forgejo_url}/user/oauth2/authentik/callback"
    }
  ]
  signing_key = data.authentik_certificate_key_pair.generated.id
}

resource "authentik_application" "forgejo" {
  name              = "Forgejo"
  slug              = "forgejo"
  protocol_provider = authentik_provider_oauth2.forgejo.id
}

# forgejo-users grubundaki herkes erişebilir
resource "authentik_policy_binding" "forgejo_users" {
  target = authentik_application.forgejo.uuid
  group  = authentik_group.groups["forgejo-users"].id
  order  = 0
}

# Forgejo'ya Authentik OAuth2 kaynağını otomatik ekle
resource "terraform_data" "forgejo_configure_oauth" {
  triggers_replace = [
    authentik_provider_oauth2.forgejo.client_secret,
  ]

  connection {
    type        = local.ssh_connection.type
    user        = local.ssh_connection.user
    host        = local.ssh_connection.host
    private_key = local.ssh_connection.private_key
  }

  # Script'i sunucuya yaz — tırnak sorununu tamamen ortadan kaldırır
  provisioner "file" {
    content = <<-EOT
      #!/bin/sh
      set -e
      if gitea admin auth list 2>/dev/null | grep -q authentik; then
        echo "authentik OAuth source already exists, skipping"
        exit 0
      fi
      gitea admin auth add-oauth \
        --name authentik \
        --provider openidConnect \
        --key forgejo \
        --secret "${authentik_provider_oauth2.forgejo.client_secret}" \
        --auto-discover-url "http://${var.remote_host}:${local.authentik_http_port}/application/o/forgejo/.well-known/openid-configuration"
    EOT
    destination = "/tmp/forgejo_oauth_setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo docker cp /tmp/forgejo_oauth_setup.sh forgejo:/tmp/forgejo_oauth_setup.sh",
      "sudo docker exec forgejo sh /tmp/forgejo_oauth_setup.sh",
      "rm -f /tmp/forgejo_oauth_setup.sh",
    ]
  }

  depends_on = [
    terraform_data.forgejo_deploy,
    authentik_application.forgejo,
  ]
}

output "forgejo_oidc" {
  value = {
    client_id     = authentik_provider_oauth2.forgejo.client_id
    client_secret = authentik_provider_oauth2.forgejo.client_secret
    discovery_url = "http://${var.remote_host}:${local.authentik_http_port}/application/o/forgejo/.well-known/openid-configuration"
  }
  sensitive = true
}
