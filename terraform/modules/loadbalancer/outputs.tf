# (6) OUTPUT BLOCKS
output "enabled" {
  description = "Whether MetalLB was installed."
  value       = var.enabled
}

output "address_pool" {
  description = "IP range MetalLB assigns to LoadBalancer Services."
  value       = var.enabled ? var.address_pool : ""
}
