resource "kubernetes_namespace_v1" "vault" {
  metadata { name = var.namespace }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = var.namespace
  wait       = true
  timeout    = 300

  values = [
    yamlencode({
      server = {
        standalone = {
          enabled = true
          config  = <<-EOF
          ui = true
          listener "tcp" {
            tls_disable = 1
            address     = "[::]:8200"
          }
          storage "file" {
            path = "/vault/data"
          }
        EOF
        }
        service = {
          type     = "NodePort"
          nodePort = var.node_port
        }
      }
      ui = {
        enabled         = true
        serviceType     = "NodePort"
        serviceNodePort = var.node_port_ui # ← ayrı port
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.vault]
}

resource "vault_jwt_auth_backend" "oidc" {
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "http://${var.base_ip}:${var.authentik_port}/application/o/vault/"
  oidc_client_id     = "vault"
  oidc_client_secret = var.vault_client_secret

  depends_on = [helm_release.vault]
}

resource "vault_jwt_auth_backend_role" "default" {
  backend         = vault_jwt_auth_backend.oidc.path
  role_name       = "default"
  token_policies  = ["default"]
  bound_audiences = ["vault"]
  user_claim      = "sub"
  role_type       = "oidc"

  allowed_redirect_uris = [
    "http://${var.base_ip}:${var.node_port}/ui/vault/auth/oidc/oidc/callback"
  ]

  depends_on = [vault_jwt_auth_backend.oidc]
}
