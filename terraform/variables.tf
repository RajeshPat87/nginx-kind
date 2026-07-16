variable "kubeconfig" {
  description = "Path to the kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context for the kind cluster."
  type        = string
  default     = "kind-nginx-kind"
}

variable "apps_namespace" {
  description = "Namespace for demo apps, ingresses, TLS and auth secrets."
  type        = string
  default     = "apps"
}

variable "data_namespace" {
  description = "Namespace for PostgreSQL."
  type        = string
  default     = "data"
}

variable "domain" {
  description = "Base domain used by the demo ingress hosts."
  type        = string
  default     = "example.com"
}

# ---- ingress-nginx ----
variable "ingress_chart_version" {
  description = "ingress-nginx Helm chart version."
  type        = string
  default     = "4.11.3"
}

# ---- ingress HA (MetalLB LoadBalancer + multiple controller replicas) ----
variable "ingress_ha_enabled" {
  description = "Run ingress-nginx in HA mode: multiple replicas behind a MetalLB LoadBalancer. Default (false) keeps the single hostPort replica reachable on localhost."
  type        = bool
  default     = false
}

variable "ingress_replica_count" {
  description = "Controller replicas when ingress_ha_enabled=true. Must be <= the kind node count (3): pod anti-affinity is required-during-scheduling, so extra replicas stay Pending. At 3 one replica lands on the control-plane and keeps localhost:80 reachable."
  type        = number
  default     = 3

  validation {
    condition     = var.ingress_replica_count >= 1 && var.ingress_replica_count <= 3
    error_message = "ingress_replica_count must be between 1 and 3 — kind/cluster.yaml defines 3 nodes and anti-affinity allows one controller replica per node."
  }
}

variable "metallb_chart_version" {
  description = "MetalLB Helm chart version (only used when ingress_ha_enabled=true)."
  type        = string
  default     = "0.14.8"
}

variable "metallb_address_pool" {
  description = "IP range MetalLB assigns to LoadBalancer Services. Must be inside the kind Docker network subnet (docker network inspect kind)."
  type        = string
  default     = "172.18.255.200-172.18.255.250"
}

# ---- PostgreSQL ----
variable "pg_user" {
  description = "PostgreSQL application username."
  type        = string
  default     = "appuser"
}

variable "pg_password" {
  description = "PostgreSQL application password."
  type        = string
  default     = "apppass123"
  sensitive   = true
}

variable "pg_database" {
  description = "PostgreSQL application database."
  type        = string
  default     = "appdb"
}

# ---- monitoring (optional / RAM heavy) ----
variable "enable_monitoring" {
  description = "Install kube-prometheus-stack (needs extra RAM)."
  type        = bool
  default     = false
}

variable "monitoring_chart_version" {
  description = "kube-prometheus-stack Helm chart version."
  type        = string
  default     = "65.5.1"
}

# ---- demo apps ----
variable "demo_image" {
  description = "Image used by the demo backend apps (echoes host/headers)."
  type        = string
  default     = "traefik/whoami:v1.10.4"
}
