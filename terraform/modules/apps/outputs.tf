# (6) OUTPUT BLOCKS
output "namespace" {
  description = "Namespace where demo apps run."
  value       = kubernetes_namespace.apps.metadata[0].name
}

output "app_names" {
  description = "Names of the deployed demo backends."
  value       = keys(var.demo_apps)
}
