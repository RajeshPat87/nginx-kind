# (6) OUTPUT BLOCKS
output "namespace" {
  description = "Namespace where the ingress controller runs."
  value       = helm_release.ingress_nginx.namespace
}

output "controller_service" {
  description = "Name of the ingress controller Service (read via data source)."
  value       = data.kubernetes_service.controller.metadata[0].name
}

output "controller_service_type" {
  description = "Service type of the ingress controller."
  value       = data.kubernetes_service.controller.spec[0].type
}
