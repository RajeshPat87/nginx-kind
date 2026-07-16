# (6) OUTPUT BLOCKS
output "namespace" {
  description = "Namespace where PostgreSQL runs."
  value       = kubernetes_namespace.data.metadata[0].name
}

output "service_fqdn" {
  description = "In-cluster DNS name of the PostgreSQL service."
  value       = "postgres.${kubernetes_namespace.data.metadata[0].name}.svc.cluster.local:5432"
}

output "secret_name" {
  description = "Name of the credentials Secret."
  value       = kubernetes_secret.postgres.metadata[0].name
}
