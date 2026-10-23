resource "minikube_cluster" "docker" {
  driver       = "docker"
  cluster_name = var.cluster_name
  cpus         = "4"
  memory = "6000mb"
  cni = "bridge"
  addons = [
    "default-storageclass",
    "storage-provisioner"
  ]
}

module "argocd" {
  source = "./modules/argocd"

  depends_on = [minikube_cluster.docker]
}