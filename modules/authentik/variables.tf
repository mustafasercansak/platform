variable "secret_key" {
  type      = string
  sensitive = true
}
variable "pg_pass" {
  type      = string
  sensitive = true
}
variable "bootstrap_password" {
  type      = string
  sensitive = true
}
variable "bootstrap_token" {
  type      = string
  sensitive = true
}
variable "namespace" {
  type    = string
  default = "authentik"
}
variable "node_port" {
  type    = number
  default = 30900
}
variable "base_ip" {
  type    = string
  default = "192.168.137.11"
}

variable "app_ports" {
  type = map(number)
  default = {
    authentik = 9000
    gitea     = 3000
    grafana   = 3001
    wikijs    = 3002
    vault     = 8200
    portainer = 9000
    traefik   = 9090
  }
}
