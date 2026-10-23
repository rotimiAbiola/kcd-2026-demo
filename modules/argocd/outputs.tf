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