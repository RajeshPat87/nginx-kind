# (6) OUTPUT BLOCKS — surface module outputs at the root.
output "ingress_namespace" {
  description = "Namespace where the ingress controller runs."
  value       = module.ingress.namespace
}

output "ingress_controller_service" {
  description = "Ingress controller Service (read via a data block)."
  value       = "${module.ingress.controller_service} (${module.ingress.controller_service_type})"
}

output "ingress_external_ip" {
  description = "MetalLB LoadBalancer IP in HA mode (empty in default mode). Export as INGRESS_IP for the test suite."
  value       = module.ingress.controller_external_ip
}

output "apps_namespace" {
  value = module.apps.namespace
}

output "demo_apps" {
  value = module.apps.app_names
}

output "data_namespace" {
  value = module.database.namespace
}

output "postgres_service" {
  description = "In-cluster DNS name of the PostgreSQL service."
  value       = module.database.service_fqdn
}

output "monitoring_enabled" {
  value = module.monitoring.enabled
}

output "grafana_url" {
  description = "Grafana URL via the ingress (resolve the host to the ingress LoadBalancer IP)."
  value       = module.monitoring.grafana_url
}

output "next_steps" {
  value = "Run 'make config' (Ansible post-config) then 'make test' to exercise every ingress scenario."
}
