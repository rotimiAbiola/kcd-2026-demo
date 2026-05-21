variable "kubernetes_version" {
  description = "Version of Kubernetes to setup the cluster with"
  type = string
  default = "v1.35.1"

}

variable "argocd_server_addr" {
  description = "Address of the Argocd server."
  type        = string
  default = "localhost:8080" # Port-forwarding to argocd-server service
}
variable "argocd_username" {
  description = "Username for Argocd authentication."
  type        = string
}

variable "argocd_password" {
  description = "Password for Argocd authentication."
  type        = string
  sensitive   = true
}

variable "install_falco" {
  description = "Install falco?"
  type = bool
  default = false
}

variable "falco_slack_webhook_url" {
  description = "Slack webhook URL used by Falcosidekick."
  type        = string
  sensitive   = true
}

variable "falco_alert_minimum_priority" {
  description = "Minimum Falco alert priority sent to Slack by Falcosidekick."
  type        = string
  default     = "warning"
}

variable "install_gatekeeper" {
  description = "Install Gatekeeper?"
  type = bool
  default = false
}