locals {
  groups = {
    admins      = { name = "admins", is_superuser = true }
    developers  = { name = "developers", is_superuser = false }
    viewers     = { name = "viewers", is_superuser = false }
    vault_users = { name = "vault-users", is_superuser = false }
  }

  users = {
    admin = {
      username = "admin"
      name     = "Admin"
      email    = "admin@platform.local"
      groups   = ["admins"]
    }
  }

  # Hangi grup hangi uygulamaya erişebilir
  app_group_bindings = {
    gitea     = ["admins", "developers"]
    grafana   = ["admins", "developers", "viewers"]
    wikijs    = ["admins", "developers", "viewers"]
    portainer = ["admins"]
    traefik   = ["admins"]
    vault     = ["admins", "vault_users"]
  }
}

# Grupları oluştur
resource "authentik_group" "groups" {
  for_each     = local.groups
  name         = each.value.name
  is_superuser = each.value.is_superuser
}

# Kullanıcıları oluştur
resource "authentik_user" "users" {
  for_each = local.users

  username = each.value.username
  name     = each.value.name
  email    = each.value.email
  password = random_password.all["${each.key}_pass"].result

  groups = [
    for g in each.value.groups : authentik_group.groups[g].id
  ]

  depends_on = [authentik_group.groups]
}

# Uygulama-grup policy binding
resource "authentik_policy_binding" "app_groups" {
  for_each = {
    for pair in flatten([
      for app, groups in local.app_group_bindings : [
        for group in groups : {
          key   = "${app}-${group}"
          app   = app
          group = group
        }
      ]
    ]) : pair.key => pair
  }

  target = authentik_application.apps[each.value.app].uuid
  group  = authentik_group.groups[each.value.group].id
  order  = 0

  depends_on = [authentik_application.apps, authentik_group.groups]
}
