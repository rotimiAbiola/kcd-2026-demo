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

# variable "falcosidekick_slack_minimum_priority" {
#   description = "Minimum Falco alert priority sent to Slack by Falcosidekick."
#   type        = string
#   default     = "warning"
# }

variable "argocd_username" {
  description = "Username for Argocd authentication."
  type        = string
}

variable "argocd_password" {
  description = "Password for Argocd authentication."
  type        = string
  sensitive   = true
}

variable "install_gatekeeper" {
  description = ""
}