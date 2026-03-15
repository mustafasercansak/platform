resource "kubernetes_namespace_v1" "gitea" {
  metadata { name = var.namespace }
}

resource "helm_release" "gitea" {
  name            = "gitea"
  repository      = "https://dl.gitea.com/charts/"
  chart           = "gitea"
  namespace       = var.namespace
  wait            = false
  timeout         = 300
  cleanup_on_fail = true

  values = [
    yamlencode({
      service = {
        http = {
          type     = "NodePort"
          nodePort = var.node_port
        }
      }
      gitea = {
        admin = {
          username = "gitea-admin"
          password = var.admin_pass
          email    = "admin@platform.local"
        }
        config = {
          database = {
            DB_TYPE = "postgres"
            HOST    = "gitea-postgresql:5432"
            NAME    = "gitea"
            USER    = "gitea"
            PASSWD  = var.pg_pass
          }
          server = {
            ROOT_URL  = "http://${var.base_ip}:${var.node_port}"
            HTTP_PORT = 3000
          }
          cache = {
            ADAPTER = "memory" # ← valkey yerine memory
          }
          queue = {
            TYPE = "level" # ← valkey yerine level
          }
          session = {
            PROVIDER = "memory" # ← valkey yerine memory
          }
        }
      }
      postgresql = {
        enabled = true
        global = {
          postgresql = {
            auth = {
              password = var.pg_pass
              database = "gitea"
              username = "gitea"
            }
          }
        }
      }
      "postgresql-ha" = {
        enabled = false
      }
      "valkey-cluster" = {
        enabled = false # ← kapat
      }
      redis-cluster = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.gitea]
}
