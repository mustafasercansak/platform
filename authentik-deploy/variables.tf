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

variable "authentik_app_path" {
  type        = string
  description = "Authentik kurulum dizini"
  default     = "/opt/authentik"
}

variable "authentik_http_port" {
  type    = number
  default = 9000
}

variable "authentik_https_port" {
  type    = number
  default = 9443
}
