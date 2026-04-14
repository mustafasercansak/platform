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

variable "n8n_port" {
  type    = number
  default = 5678
}

