terraform {
  required_providers {
    minikube = {
      source  = "scott-the-programmer/minikube"
      version = "0.6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.0"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "~> 7.0"
    }
  }
}

provider "minikube" {
  kubernetes_version = "v1.35.1"
}

provider "kubernetes" {
  host = minikube_cluster.docker.host

  client_certificate     = minikube_cluster.docker.client_certificate
  client_key             = minikube_cluster.docker.client_key
  cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = minikube_cluster.docker.host
    client_certificate     = minikube_cluster.docker.client_certificate
    client_key             = minikube_cluster.docker.client_key
    cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
  }
}

provider "argocd" {
#   server_addr = "argocd.minikube.local:80"
    server_addr = "localhost:8080" # Port-forwarding to argocd-server service
  # Use gRPC Web over HTTPS (as configured in HTTPRoute)
  plain_text = true
  insecure   = true
  grpc_web   = true

  # Use basic auth instead of token
  username = var.argocd_username
  password = var.argocd_password
  # auth_token = var.argocd_auth_token
}