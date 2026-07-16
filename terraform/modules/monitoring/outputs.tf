# (6) OUTPUT BLOCKS
output "enabled" {
  description = "Whether monitoring was installed."
  value       = var.enabled
}

output "namespace" {
  description = "Namespace of the monitoring stack (empty when disabled)."
  value       = var.enabled ? var.namespace : ""
}

output "grafana_url" {
  description = "Grafana URL via the ingress (empty when monitoring or ingress is disabled)."
  value       = var.enabled && var.grafana_host != "" ? "http://${var.grafana_host}" : ""
}
