variable "remote_host" {
  type    = string
  default = "192.170.6.11"
}

variable "remote_user" {
  type    = string
  default = "vys"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

variable "portainer_http_port" {
  type    = number
  default = 9001
}

variable "portainer_https_port" {
  type    = number
  default = 8443
}

variable "portainer_url" {
  type    = string
  default = "http://192.170.6.11:9001/"
}

variable "portainer_app_path" {
  type    = string
  default = "/opt/portainer"
}

variable "authentik_url" {
  type    = string
  default = "http://192.170.6.11:9000"
}

variable "oidc_client_id" {
  type    = string
  default = "portainer"
}

variable "oidc_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}
