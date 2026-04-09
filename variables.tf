variable "remote_host" {
  type        = string
  description = "Uzak Ubuntu makinesinin IP adresi"
  default     = "192.168.137.11" # İstersen varsayılan bırakabilirsin
}

variable "remote_user" {
  type        = string
  description = "Uzak Ubuntu makinesinin kullanıcı adı"
  default     = "sa" # İstersen varsayılan bırakabilirsin
}