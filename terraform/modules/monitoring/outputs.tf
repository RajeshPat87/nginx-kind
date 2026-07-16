# (6) OUTPUT BLOCKS
output "enabled" {
  description = "Whether monitoring was installed."
  value       = var.enabled
}

output "namespace" {
  description = "Namespace of the monitoring stack (empty when disabled)."
  value       = var.enabled ? var.namespace : ""
}
