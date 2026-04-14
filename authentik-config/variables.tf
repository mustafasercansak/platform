variable "authentik_url" {
  type        = string
  description = "Authentik instance URL"
  default     = "http://192.170.6.11:9000"
}

variable "authentik_token" {
  type        = string
  description = "Authentik Bootstrap Token"
  sensitive   = true
  default     = "fBoBDFIwFpkrXvGlf50PXLl4Jx9c8YSsyRu947SmIILHzmucqxJEt9DNTZlPxu09"
}

variable "remote_host" {
  type    = string
  default = "192.170.6.11"
}

variable "portainer_url" {
  type    = string
  default = "http://192.170.6.11:9001/"
}

variable "forgejo_url" {
  type    = string
  default = "http://192.170.6.11:3002"
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
      password = "password123"
      groups   = ["platform-admins", "forgejo-users", "wikijs-users", "grafana-admins", "portainer-admins"]
    },
    {
      username = "merve.onder"
      name     = "Merve Onder"
      email    = "merve.onder@example.com"
      password = "password123"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "caglar.guldiken"
      name     = "Çağlar Güldiken"
      email    = "caglar.guldiken@example.com"
      password = "password123"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "ogun.kethuda"
      name     = "Ogün Kethüda"
      email    = "ogun.kethuda@example.com"
      password = "password123"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "nurfem.taysi"
      name     = "Nurfem Taysı"
      email    = "nurfem.taysi@example.com"
      password = "password123"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "baris.duran"
      name     = "Barış Duran"
      email    = "baris.duran@example.com"
      password = "password123"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "gokhan.kucukoglu"
      name     = "Gökhan Küçükoğlu"
      email    = "gokhan.kucukoglu@example.com"
      password = "password123"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "alperen.akar"
      name     = "Alperen Akar"
      email    = "alperen.akar@example.com"
      password = "password123"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "selcuk.anacoglu"
      name     = "Selçuk Anaçoğlu"
      email    = "selcuk.anacoglu@example.com"
      password = "password123"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "elif.sezer"
      name     = "Elif Sezer"
      email    = "elif.sezer@example.com"
      password = "password123"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    },
    {
      username = "sena.nal"
      name     = "Sena Nal"
      email    = "sena.nal@example.com"
      password = "password123"
      groups   = ["forgejo-users", "wikijs-users", "grafana-users"]
    }
  ]
}
