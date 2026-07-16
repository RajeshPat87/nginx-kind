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

output "controller_external_ip" {
  description = "LoadBalancer IP assigned by MetalLB in HA mode (empty otherwise). Use it as INGRESS_IP when running the test suite."
  value       = try(data.kubernetes_service.controller.status[0].load_balancer[0].ingress[0].ip, "")
}
