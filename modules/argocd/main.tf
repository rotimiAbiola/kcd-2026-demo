terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}

resource "helm_release" "argocd" {
  name             = var.release_name
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.10.5"
  namespace        = var.namespace
  create_namespace = true
  values = [yamlencode({
    configs = {
      params = {
        "server.insecure" = true
      }
    }
    controller = {
      resources = {
        requests = { cpu = "250m", memory = "256Mi" }
        limits   = { cpu = "500m", memory = "512Mi" }
      }
      livenessProbe = {
        enabled = true
      }
    }

    applicationSet = {
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
        limits   = { cpu = "100m", memory = "128Mi" }
      }
      readinessProbe = {
        enabled = true
      }
      livenessProbe = {
        enabled = true
      }
    }

    redis = {
      resources = {
        requests = { cpu = "100m", memory = "64Mi" }
        limits   = { cpu = "200m", memory = "128Mi" }
      }
      readinessProbe = {
        enabled = true
      }
      livenessProbe = {
        enabled = true
      }
    }

    repoServer = {
      resources = {
        requests = { cpu = "10m", memory = "64Mi" }
        limits   = { cpu = "50m", memory = "128Mi" }
      }
    }

    server = {
      resources = {
        requests = { cpu = "50m", memory = "64Mi" }
        limits   = { cpu = "100m", memory = "128Mi" }
      }

      service = {
        type = "NodePort"

        nodePortHttp  = 30080
        nodePortHttps = 30443
      }

      ingress = {
        enabled = false
      }
    }

    dex = {
      enabled = false
    }
    notifications = {
      enabled = false
    }
  })]
  wait    = true
  timeout = 600
}

