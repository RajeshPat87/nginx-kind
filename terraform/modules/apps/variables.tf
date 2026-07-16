# (5) VARIABLE BLOCKS — module inputs
variable "namespace" {
  description = "Namespace for demo apps, ingresses and their secrets."
  type        = string
}

variable "labels" {
  description = "Common labels applied to module resources."
  type        = map(string)
  default     = {}
}

variable "demo_apps" {
  description = "Map of demo backend name => settings (replicas)."
  type = map(object({
    replicas = number
  }))
}

variable "demo_image" {
  description = "Image used by the demo backend apps."
  type        = string
}

variable "chart_path" {
  description = "Path to the local demo-app Helm chart."
  type        = string
}

variable "data_namespace" {
  description = "Namespace of the PostgreSQL service (for Adminer default server)."
  type        = string
}
