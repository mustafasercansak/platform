 terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.12.1"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}

# --- Paylaşılan Veriler ---

data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-explicit-consent"
}

data "authentik_flow" "default-invalidation-flow" {
  slug = "default-invalidation-flow"
}

data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

# --- Scope Mappings ---

data "authentik_property_mapping_provider_scope" "scopes" {
  for_each = toset(["openid", "email", "profile"])
  managed  = "goauthentik.io/providers/oauth2/scope-${each.key}"
}

resource "authentik_property_mapping_provider_scope" "gitlab" {
  name       = "gitlab-compatibility"
  scope_name = "openid"
  expression = <<-EOT
    return {
        "id": int(user.pk),
        "username": user.username,
        "name": user.name,
        "email": user.email
    }
  EOT
}

# --- Gruplar ---

resource "authentik_group" "groups" {
  for_each = toset(distinct(flatten([
    for u in var.platform_users : u.groups
  ])))

  name = each.key
}

# --- Kullanıcılar ---

resource "authentik_user" "users" {
  for_each = { for u in var.platform_users : u.username => u }

  username = each.value.username
  name     = each.value.name
  email    = each.value.email
  password = each.value.password

  groups = [
    for g in each.value.groups : authentik_group.groups[g].id
  ]
}
