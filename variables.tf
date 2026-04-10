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

variable "portainer_http_port" {
  type        = number
  description = "Portainer HTTP portu"
  default     = 9001
}

variable "portainer_https_port" {
  type        = number
  description = "Portainer HTTPS portu"
  default     = 8443
}

variable "portainer_url" {
  type        = string
  description = "Portainer'a erişilen URL (OIDC Redirect için)"
  default     = "http://192.170.6.11:9001/"
}

variable "forgejo_http_port" {
  type    = number
  default = 3000
}

variable "forgejo_ssh_port" {
  type    = number
  default = 2222
}

variable "forgejo_url" {
  type    = string
  default = "http://192.170.6.11:3000"
}

variable "forgejo_admin_user" {
  type    = string
  default = "forgejo-admin"
}

variable "platform_users" {
  description = "Authentik'te oluşturulacak kullanıcılar"
  type = list(object({
    username = string
    name     = string
    email    = string
    password = string
    groups   = list(string)
  }))
  default = [
    {
      username = "sercan.sak"
      name     = "Mustafa Sercan Sak"
      email    = "sercan.sak@example.com"
      password = "123456"
      groups   = ["platform-admins", "forgejo-users", "wikijs-users", "grafana-admins", "portainer-admins"]
    },
    {
      username = "merve.onder"
      name     = "Merve Onder"
      email    = "merve.onder@example.com"
      password = "123456"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "caglar.guldiken"
      name     = "Çağlar Güldiken"
      email    = "caglar.guldiken@example.com"
      password = "123456"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "ogun.kethuda"
      name     = "Ogün Kethüda"
      email    = "ogun.kethuda@example.com"
      password = "123456"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "nurfem.taysi"
      name     = "Nurfem Taysı"
      email    = "nurfem.taysi@example.com"
      password = "123456"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "baris.duran"
      name     = "Barış Duran"
      email    = "baris.duran@example.com"
      password = "123456"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "gokhan.kucukoglu"
      name     = "Gökhan Küçükoğlu"
      email    = "gokhan.kucukoglu@example.com"
      password = "123456"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "alperen.akar"
      name     = "Alperen Akar"
      email    = "alperen.akar@example.com"
      password = "123456"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "selcuk.anacoglu"
      name     = "Selçuk Anaçoğlu"
      email    = "selcuk.anacoglu@example.com"
      password = "123456"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "elif.sezer"
      name     = "Elif Sezer"
      email    = "elif.sezer@example.com"
      password = "123456"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "sena.nal"
      name     = "Sena Nal"
      email    = "sena.nal@example.com"
      password = "123456"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
  ]
}
