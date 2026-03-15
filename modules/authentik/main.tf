resource "kubernetes_namespace_v1" "authentik" {
  metadata { name = var.namespace }
}

resource "helm_release" "authentik" {
  name             = "authentik"
  repository       = "https://charts.goauthentik.io"
  chart            = "authentik"
  namespace        = var.namespace
  create_namespace = true
  wait             = true
  timeout          = 600
  wait_for_jobs    = true

  values = [
    yamlencode({
      authentik = {
        secret_key = var.secret_key
        postgresql = {
          password = var.pg_pass
        }
      }
      postgresql = {
        enabled = true
        auth = {
          password = var.pg_pass
        }
      }
      global = {
        env = [
          {
            name  = "AUTHENTIK_BOOTSTRAP_PASSWORD"
            value = var.bootstrap_password
          },
          {
            name  = "AUTHENTIK_BOOTSTRAP_TOKEN"
            value = var.bootstrap_token
          }
        ]
      }
      server = {
        service = {
          type         = "NodePort"
          nodePortHttp = 30900
        }
      }
    })
  ]
}
