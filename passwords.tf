locals {
  passwords = {
    pg_pass            = { length = 36, special = false }
    secret_key         = { length = 60, special = false }
    bootstrap_token    = { length = 60, special = false }
    bootstrap_password = { length = 24, special = false }
    devRootToken       = { length = 36, special = false }
    gitea_admin        = { length = 24, special = false }
    grafana_admin      = { length = 24, special = false }
    vault_root         = { length = 36, special = false }
    admin_pass         = { length = 24, special = false }
  }
}

resource "random_password" "all" {
  for_each = local.passwords
  length   = each.value.length
  special  = each.value.special
}
