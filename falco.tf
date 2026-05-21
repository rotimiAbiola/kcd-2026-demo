resource "random_string" "falco_ui_password_minikube" {
  count            = var.install_falco ? 1 : 0
  length           = 16
  special          = true
  override_special = "_@"
}

module "falco" {
  source = "./modules/argocd-helm-app"
  count            = var.install_falco ? 1 : 0

  application_name = "falco"
  namespace        = "falco"
  project          = "default"
  repository_url   = "https://falcosecurity.github.io/charts"
  chart_name       = "falco"
  chart_version    = "8.0.2"
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
      # If `minikube ssh -- uname -r` returns < 5.8, swap to:
      # kind = "kmod"
      modernEbpf = {
        leastPrivileged   = false
        bufSizePreset     = 4  # keep low — minikube is single-node, low throughput
        cpusForEachBuffer = 2
        sysfsMount        = true
      }
    }

    tty = true

    # ── No resource pressure on minikube — use minimal requests ───────────────
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

    # No nodeSelector or tolerations needed on minikube single-node
    nodeSelector = {}
    tolerations  = []

    # ── Metrics ───────────────────────────────────────────────────────────────
    # Disable on minikube unless you have kube-prometheus-stack running there too
    metrics = {
      enabled = false
    }

    serviceMonitor = {
      create = false
    }

    # ── Falco core config ─────────────────────────────────────────────────────
    falco = {
      replicaCount = 1  # minikube is single-node, no HA needed
      priority = "debug"

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
        prometheus_metrics_enabled = false  # no Prometheus on minikube
        listen_port                = 8765
      }
    }

    # ── Falcosidekick ─────────────────────────────────────────────────────────
    falcosidekick = {
      enabled  = true
      fullfqdn = false
      replicaCount = 1 

      config = {
        slack = {
          webhookurl      = var.falco_slack_webhook_url
          minimumpriority = "warning"
          messageformat   = "rule: *{{ .Rule }}* on `{{ .Hostname }}` | priority: *{{ .Priority }}* | `{{ .Output }}`"
        }
      }

      webui = {
        enabled = true
        replicaCount = 1 

        # minikube nginx ingress addon
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          annotations      = {}
          hosts = [
            {
              host  = "falco.minikube.local"
              paths = [{ path = "/" }]
            }
          ]
          tls = []  # no TLS on minikube
        }

        # Minimal resources for minikube
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

        # No auth on minikube — remove user field entirely for open access
        # or keep it if you want to test the auth flow
        user = "admin:${random_string.falco_ui_password_minikube[0].result}"

        redis = {
          enabled = true  
        }
      }
    }
  })
}

# ── Namespace PSA label ───────────────────────────────────────────────────────
# minikube doesn't enforce PSA by default but setting this is harmless
# and keeps the module consistent with your GKE pattern
# resource "kubernetes_namespace_v1" "falco_minikube" {
#   count = var.install_falco_argocd ? 1 : 0

#   metadata {
#     name = "falco"
#     labels = {
#       "pod-security.kubernetes.io/enforce" = "privileged"
#       "pod-security.kubernetes.io/audit"   = "privileged"
#       "pod-security.kubernetes.io/warn"    = "privileged"
#     }
#   }

#   lifecycle {
#     ignore_changes = [
#       metadata[0].annotations,
#       metadata[0].labels,
#     ]
#   }
# }