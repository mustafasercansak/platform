variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_rsa"
}

variable "mattermost_port" {
  type    = number
  default = 8065
}
