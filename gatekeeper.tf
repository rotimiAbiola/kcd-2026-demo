module "gatekeeper" {
  source = "./modules/argocd-helm-app"
  count  = var.install_gatekeeper ? 1 : 0

  application_name = "gatekeeper"
  namespace        = "gatekeeper-system"
  project          = "default"
  repository_url   = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart_name       = "gatekeeper"
  chart_version    = "3.22.0"
  create_namespace = false

  sync_policy = {
    automated = {
      prune       = true
      self_heal   = true
      allow_empty = false
    }
    sync_options = ["CreateNamespace=true", "ServerSideApply=true"]
  }

  values = yamlencode({

    image = {
      release = "v3.22.0"
    }

    replicas = 1

    # ── Failure policy: Ignore on minikube ────────────────────────────────────
    # Matches chart default intentionally — prevents minikube becoming
    # unschedulable if Gatekeeper pod restarts during development
    validatingWebhookFailurePolicy  = "Ignore"
    validatingWebhookTimeoutSeconds = 3

    validatingWebhookExemptNamespacesLabels = {
      "admission.gatekeeper.sh/ignore" = ["no-self-managing"]
    }

    logLevel            = "DEBUG"   # verbose for local triage
    logDenies           = true
    emitAdmissionEvents = true
    emitAuditEvents     = true

    # Faster audit cadence — tighter feedback loop in dev
    auditInterval             = 30
    constraintViolationsLimit = 20
    auditFromCache            = false

    audit = {
      resources = {
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
    }

    controllerManager = {
      # Keep chart default preferred anti-affinity — single node, required would prevent scheduling
      affinity = {
        podAntiAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              podAffinityTerm = {
                labelSelector = {
                  matchExpressions = [
                    {
                      key      = "gatekeeper.sh/operation"
                      operator = "In"
                      values   = ["webhook"]
                    }
                  ]
                }
                topologyKey = "kubernetes.io/hostname"
              }
              weight = 100
            }
          ]
        }
      }

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

      exemptNamespaces = [
        "kube-system",
        "gatekeeper-system",
        "falco",
        "argocd",
        "monitoring",
        "cert-manager",
      ]
    }

    # No ServiceMonitor on minikube
    serviceMonitor = {
      enabled = false
    }

    metricsBackends = ["prometheus"]

    disableMutation = true
  })
}

resource "kubernetes_namespace_v1" "gatekeeper_minikube" {
  count = var.install_gatekeeper ? 1 : 0

  metadata {
    name = "gatekeeper-system"
    labels = {
      "admission.gatekeeper.sh/ignore" = "no-self-managing"
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels,
    ]
  }
}

module "gpm" {
  source = "./modules/argocd-helm-app"
  count  = var.install_gatekeeper ? 1 : 0

  application_name = "gatekeeper-policy-manager"
  namespace        = "gatekeeper-system"
  project          = "default"
  repository_url   = "https://sighupio.github.io/gatekeeper-policy-manager"
  chart_name       = "gatekeeper-policy-manager"
  chart_version    = "0.14.0"
  create_namespace = false

  sync_policy = {
    automated = {
      prune       = true
      self_heal   = true
      allow_empty = false
    }
    sync_options = ["CreateNamespace=false", "ServerSideApply=true"]
  }

  values = yamlencode({

    image = {
      repository = "quay.io/sighup/gatekeeper-policy-manager"
      tag        = "v1.1.1"
      pullPolicy = "IfNotPresent"
    }

    replicaCount = 1

    rbac = {
      create = true
    }

    serviceAccount = {
      create = true
      name   = "gatekeeper-policy-manager"
    }

    service = {
      type = "ClusterIP"
      port = 8080
    }

    ingress = {
      enabled          = true
      ingressClassName = "nginx"
      annotations      = {}
      hosts = [
        {
          host  = "gpm.minikube.local"
          paths = [
            {
              path     = "/"
              pathType = "Prefix"
            }
          ]
        }
      ]
      tls = []   # no TLS on minikube
    }

    # Minimal resources for minikube
    resources = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "256Mi"
      }
    }

    config = {
      auditResults    = true
      refreshInterval = 15   # faster refresh in dev
    }
  })
}