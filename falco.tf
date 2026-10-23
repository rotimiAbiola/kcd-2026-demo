resource "random_string" "falco_ui_password_minikube" {
  count            = var.install_falco ? 1 : 0
  length           = 16
  special          = true
  override_special = "_@"
}

module "falco" {
  source = "./modules/argocd-helm-app"
  count  = var.install_falco ? 1 : 0

  application_name = "falco"
  namespace        = "falco"
  project          = "default"
  repository_url   = "https://falcosecurity.github.io/charts"
  chart_name       = "falco"
  chart_version    = "9.2.1"
  create_namespace = false

  sync_policy = {
    automated = {
      prune       = true
      self_heal   = false
      allow_empty = false
    }
    sync_options = ["CreateNamespace=true", "ServerSideApply=true"]
  }

  values = yamlencode({

    # ── Driver ────────────────────────────────────────────────────────────────
    driver = {
      kind = "modern_ebpf"
      modernEbpf = {
        leastPrivileged   = false
        bufSizePreset     = 4
        cpusForEachBuffer = 2
        sysfsMount        = true
      }
    }

    tty = true

    resources = {
      requests = {
        cpu    = "100m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
    }

    nodeSelector = {}
    tolerations  = []

    metrics = {
      enabled = false
    }

    serviceMonitor = {
      create = false
    }

    falco = {
      replicaCount = 1 
      priority     = "debug"

      json_output                         = true
      json_include_output_property        = true
      json_include_output_fields_property = true
      json_include_tags_property          = true

      log_level  = "info"
      log_stderr = true
      log_syslog = false

      stdout_output = {
        enabled = true
      }

      syslog_output = {
        enabled = false
      }

      syscall_event_drops = {
        threshold = 0.1
        actions   = ["log", "alert"]
        rate      = 0.03333
        max_burst = 1
      }

      webserver = {
        enabled                    = true
        prometheus_metrics_enabled = false 
        listen_port                = 8765
      }
    }

    falcoctl = {
      artifact = {
        install = {
          resources = {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "100m", memory = "128Mi" }
          }
        }
        follow = {
          resources = {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "100m", memory = "128Mi" }
          }
        }
      }
    }

    falcosidekick = {
      enabled      = true
      fullfqdn     = false
      replicaCount = 1

      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "200m", memory = "128Mi" }
      }

      config = {
        slack = {
          webhookurl      = var.falco_slack_webhook_url
          minimumpriority = var.falco_alert_minimum_priority
          messageformat   = "rule: *{{ .Rule }}* on `{{ .Hostname }}` | priority: *{{ .Priority }}* | `{{ .Output }}`"
        }
      }

      webui = {
        enabled      = true
        replicaCount = 1

        service = {
          type       = "NodePort"
          port       = 2802
          nodePort   = 30282
          targetPort = 2802
        }

        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "128Mi"
          }
        }

        loglevel = "info"

        user = "admin:${random_string.falco_ui_password_minikube[0].result}"

        redis = {
          enabled = true
        }
      }
    }
  })
}