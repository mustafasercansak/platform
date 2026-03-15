output "namespace" { value = var.namespace }
output "node_port" { value = var.node_port }
output "endpoint" { value = "http://${var.base_ip}:${var.node_port}" }
