variable "namespace" {
  description = "Kubernetes namespace where Argo CD will be installed."
  type        = string
  default     = "argocd"
}

variable "release_name" {
  description = "Helm release name for Argo CD."
  type        = string
  default     = "argocd"
}

variable "hostname" {
  description = "Hostname for local Argo CD ingress access."
  type        = string
  default     = "argocd.minikube.local"
}