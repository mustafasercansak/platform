variable "namespace" {
  type    = string
  default = "vault"
}
variable "node_port" {
  type    = number
  default = 8200
}
variable "vault_root_token" {
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
variable "vault_client_secret" {
  type      = string
  sensitive = true
}
variable "node_port_ui" {
  type    = number
  default = 30821
}
