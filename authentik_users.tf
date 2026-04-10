# Tüm kullanıcıların group listesinden benzersiz grupları otomatik oluştur
resource "authentik_group" "groups" {
  for_each = toset(distinct(flatten([
    for u in var.platform_users : u.groups
  ])))

  name = each.key

  depends_on = [terraform_data.authentik_deploy]
}

# Kullanıcılar
resource "authentik_user" "users" {
  for_each = { for u in var.platform_users : u.username => u }

  username = each.value.username
  name     = each.value.name
  email    = each.value.email
  password = each.value.password

  groups = [
    for g in each.value.groups : authentik_group.groups[g].id
  ]

  depends_on = [terraform_data.authentik_deploy]
}
