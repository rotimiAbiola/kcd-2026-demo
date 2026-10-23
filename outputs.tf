output "falco_ui_password_minikube" {
  value     = var.install_falco ? random_string.falco_ui_password_minikube[0].result : null
  sensitive = true
}
