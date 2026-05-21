resource "minikube_cluster" "docker" {
  driver       = "docker"
  cluster_name = "tf-test-cluster"
  addons = [
    "default-storageclass",
    "storage-provisioner",
    "ingress"
  ]
}

module "argocd" {
  source = "./modules/argocd"

  depends_on = [minikube_cluster.docker]
}