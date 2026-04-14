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

variable "forgejo_app_path" {
  type    = string
  default = "/opt/forgejo"
}
