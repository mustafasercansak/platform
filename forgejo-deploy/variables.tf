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

variable "forgejo_http_port" {
  type    = number
  default = 3002
}

variable "forgejo_ssh_port" {
  type    = number
  default = 2222
}

variable "forgejo_url" {
  type    = string
  default = "http://192.170.6.11:3002"
}

variable "forgejo_admin_user" {
  type    = string
  default = "forgejo-admin"
}

variable "authentik_url" {
  type    = string
  default = "http://192.170.6.11:9000"
}

variable "oidc_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}
