terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}

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

resource "helm_release" "argocd" {
  name             = var.release_name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.5.14"
  namespace        = var.namespace
  create_namespace = true
  values = [yamlencode({
    configs = {
      params = {
        "server.insecure" = true
      }
    }
    server = {
      ingress = {
        enabled          = true
        ingressClassName = "nginx"
        hostname         = var.hostname
        path             = "/"
        pathType         = "Prefix"
        tls              = false
      }
    }
  })]
  wait    = true
  timeout = 600
}

output "release_name" {
  description = "Argo CD Helm release name."
  value       = helm_release.argocd.name
}

output "namespace" {
  description = "Namespace where Argo CD is installed."
  value       = helm_release.argocd.namespace
}

output "url" {
  description = "Local URL for Argo CD UI."
  value       = "http://${var.hostname}"
}
