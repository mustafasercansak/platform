variable "base_ip" {
  type    = string
  default = "192.168.137.11"
}

variable "app_ports" {
  type = map(number)
  default = {
    authentik = 30900
    gitea     = 30300
    grafana   = 30301
    wikijs    = 30302
    vault     = 30820
    vault_ui  = 30821
    portainer = 30303
    traefik   = 30304
  }
}
