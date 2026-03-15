output "passwords" {
  sensitive = true
  value     = { for k, v in random_password.all : k => v.result }
}
output "dashboard_token" {
  sensitive = true
  value     = kubernetes_secret_v1.dashboard_token.data["token"]
}
