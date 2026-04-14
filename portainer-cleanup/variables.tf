variable "remote_host" {
  type        = string
  description = "Uzak Ubuntu makinesinin IP adresi"
  default     = "192.170.6.11"
}

variable "remote_user" {
  type        = string
  description = "Uzak Ubuntu makinesinin kullanıcı adı"
  default     = "vys"
}

variable "ssh_private_key_path" {
  type        = string
  description = "SSH private key dosya yolu"
  default     = "~/.ssh/id_rsa"
}

variable "portainer_app_path" {
  type        = string
  description = "Portainer kurulum dizini"
  default     = "/opt/portainer"
}
