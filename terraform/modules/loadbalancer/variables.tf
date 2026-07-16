# (5) VARIABLE BLOCKS — module inputs
variable "enabled" {
  description = "Install MetalLB. Only needed for the HA ingress use-case."
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Namespace for the MetalLB controller and speaker."
  type        = string
  default     = "metallb-system"
}

variable "chart_version" {
  description = "MetalLB Helm chart version."
  type        = string
}

variable "address_pool" {
  description = "IP range MetalLB hands out. Must be inside the kind Docker network subnet."
  type        = string
}
