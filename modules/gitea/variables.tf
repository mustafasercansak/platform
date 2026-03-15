variable "namespace" {
  type    = string
  default = "gitea"
}
variable "node_port" {
  type    = number
  default = 3000
}
variable "pg_pass" {
  type      = string
  sensitive = true
}
variable "admin_pass" {
  type      = string
  sensitive = true
}
variable "base_ip" {
  type = string
}
variable "authentik_port" {
  type    = number
  default = 30900
}

variable "oidc" {
  type = object({
    client_id     = string
    client_secret = string
  })
  sensitive = true
}

variable "gitea_provider" {
  description = "Gitea provider config"
  type = object({
    base_url = string
    username = string
    password = string
  })
  sensitive = true
}
