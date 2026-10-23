# kcd-lab

A local Kubernetes lab for **"From Admission to Runtime: Closing the Kubernetes Security Gap with Gatekeeper and Falco"** (KCD Nigeria 2026). It stands up a minikube cluster, installs ArgoCD, then installs [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/) and [Falco](https://falco.org/) as ArgoCD-managed Applications, plus a set of demo policies and runtime triggers you can walk through live.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [minikube](https://minikube.sigs.k8s.io/docs/start/) (tested with v1.38.1)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (the `docker` driver), with **at least 6.5GB memory allocated** (Settings → Resources). The cluster requests 6GB; Docker Desktop needs headroom on top of that for its own VM.
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [helm](https://helm.sh/docs/intro/install/) (only needed if you want to inspect chart values yourself, Terraform drives the actual installs)

## Why this is a two-batch apply, not one

`terraform apply` configures every provider declared in the repo up front, including the `argocd` provider (`providers.tf`), which needs a reachable ArgoCD API and valid credentials. On a cluster that doesn't exist yet, that's impossible, there's no ArgoCD to authenticate to, and its password isn't generated until after it's installed. So the apply has to happen in two batches:

1. **Batch 1** creates the minikube cluster and installs ArgoCD (`-target`, so Terraform never tries to touch the `argocd` provider).
2. You retrieve ArgoCD's real admin password and put it in `terraform.tfvars`.
3. **Batch 2** is a normal `terraform apply`, it creates `argocd_application` resources for Gatekeeper, Falco, and the Gatekeeper Policy Manager, which ArgoCD then syncs from their upstream Helm charts.

Gatekeeper's own policies (`gatekeeper-policies/`) aren't part of either batch, they're plain Kubernetes manifests applied with `kubectl` once Gatekeeper itself is running (step 6 below).

## 1. Clone and configure

```bash
git clone <this-repo-url>
cd lab
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and fill in:
- `argocd_username = "admin"` and leave `argocd_password` as the placeholder for now, you'll replace it after batch 1.
- `falco_slack_webhook_url`, a real [Slack incoming webhook](https://api.slack.com/messaging/webhooks) if you want alerts, or any non-empty placeholder if you don't (Terraform requires the variable to have a value, even though the demo mostly watches `kubectl logs` directly).
- Leave `install_falco` and `install_gatekeeper` as `false` for now, flip them to `true` right before batch 2.

```bash
terraform init
```

## 2. Batch 1 — cluster + ArgoCD

```bash
terraform apply -target=minikube_cluster.docker -target=module.argocd -auto-approve
```

This takes 1-2 minutes: ~40s for the cluster, ~1 minute for the ArgoCD Helm release (`wait = true`, so Terraform won't return until ArgoCD's pods are actually healthy).

Verify:

```bash
kubectl --context kcd-lab -n argocd get pods
```

All pods should be `Running` except `argocd-redis-secret-init-*`, which should show `Completed`.

## 3. Connect to ArgoCD and get the real password

ArgoCD is exposed as a NodePort (`30080`/`30443`), but the simplest path from a laptop is a port-forward:

```bash
kubectl --context kcd-lab port-forward svc/argocd-server -n argocd 8080:80 &
```

Retrieve the auto-generated initial admin password:

```bash
kubectl --context kcd-lab -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Put that value into `terraform.tfvars` as `argocd_password`, and flip the feature flags on:

```hcl
argocd_password     = "<the real password>"
install_falco       = true
install_gatekeeper  = true
```

(Optional) Log in at `http://localhost:8080` with username `admin` and that password, or via the CLI: `argocd login localhost:8080 --username admin --password <password> --plaintext`.

## 4. Batch 2 — Gatekeeper, Falco, and GPM via ArgoCD

```bash
terraform apply -auto-approve
```

This creates three `argocd_application` resources. ArgoCD then syncs each from its upstream Helm chart asynchronously, Terraform returns as soon as the Applications exist, it doesn't wait for ArgoCD to finish deploying them.

Watch the rollout:

```bash
kubectl --context kcd-lab -n argocd get applications -w
```

Wait until `falco`, `gatekeeper`, and `gatekeeper-policy-manager` all show `Synced` / `Healthy`. First-time image pulls (especially Falco's eBPF driver artifacts) can take a few minutes.

## 5. Apply the Gatekeeper policies

The constraint templates, constraints, and mutators in `gatekeeper-policies/` aren't managed by ArgoCD, they're applied directly once Gatekeeper's CRDs exist:

```bash
kubectl --context kcd-lab apply -f gatekeeper-policies/templates/
kubectl --context kcd-lab apply -f gatekeeper-policies/constraints/
kubectl --context kcd-lab apply -f gatekeeper-policies/mutations/
kubectl --context kcd-lab apply -f gatekeeper-policies/config/
```

A brand-new `ConstraintTemplate` takes a moment for its CRD to register, so the `constraints/` apply right after `templates/` will likely fail on some files with `ensure CRDs are installed first`. That's a timing race, not a real error, wait a few seconds and reapply:

```bash
kubectl --context kcd-lab apply -f gatekeeper-policies/constraints/
```

(Already-created constraints show `unchanged`; the ones that failed the first time will show `created`.)

## 6. Verify everything is up

```bash
kubectl --context kcd-lab -n gatekeeper-system get pods
kubectl --context kcd-lab -n falco get pods
```

Access the UIs via port-forward:

```bash
# Gatekeeper Policy Manager
kubectl --context kcd-lab -n gatekeeper-system port-forward svc/gatekeeper-policy-manager 8081:8080 &
# http://localhost:8081

# Falco Web UI (NodePort 30282, or port-forward the same way)
kubectl --context kcd-lab -n falco port-forward svc/falco-falcosidekick-ui 8082:2802 &
# http://localhost:8082 — user/password: admin / <falco_ui_password_minikube output>
```

```bash
terraform output falco_ui_password_minikube
```

## 7. Run the demo

Every command below is meant to be typed (or pasted one at a time) live, there's no driver script, so you control the pace and can narrate each one.

### Gatekeeper (admission + mutation)

Uncomment one test case at a time in [`tests/gatekeeper-test.yaml`](tests/gatekeeper-test.yaml) and apply it to watch an individual policy deny or allow a Pod:

```bash
kubectl --context kcd-lab create namespace test
kubectl --context kcd-lab label namespace test team=workshop-demo
kubectl --context kcd-lab apply -f tests/gatekeeper-test.yaml
```

(`test` needs the `team` label, `RequireNamespaceLabel` enforces it on every namespace outside the system/infra list.)

### Falco (runtime detection)

```bash
kubectl --context kcd-lab apply -f tests/falco-test-pod.yaml
kubectl --context kcd-lab -n falco logs -l app.kubernetes.io/name=falco -f --prefix   # in a second terminal
```

Then, in a third terminal, run triggers one at a time against the pod (`falco-test-runner` in the `falco-demo` namespace), watching the matching alert land in the logs terminal after each. All three below were run against this exact cluster and chart version while writing this README, unlike some other Falco demos online, these aren't guesses, the rule names are what this cluster actually logs:

**NOTICE — `Terminal shell in container`**
```bash
kubectl --context kcd-lab exec -it -n falco-demo falco-test-runner -- sh
# type `exit` to leave; the exec itself is what fires the rule
```

**WARNING — `Read sensitive file untrusted`**
```bash
kubectl --context kcd-lab exec -n falco-demo falco-test-runner -- cat /etc/shadow
```

**CRITICAL — `Drop and execute new binary in container`**
```bash
kubectl --context kcd-lab exec -n falco-demo falco-test-runner -- sh -c "apk add --no-cache curl -q && curl --version"
```
(A binary that wasn't in the container's original image got installed and executed, a classic "attacker drops a tool" pattern.)

The Falco default rule set in this chart version only ships 25 rules (`kubectl -n falco exec <falco-pod> -c falco -- grep -c '^- rule:' /etc/falco/falco_rules.yaml` to see for yourself), noticeably fewer than older Falco versions. If you're adapting triggers from an older blog post or demo and they go quiet, check the actual rule name exists in your version before assuming your command is wrong.

Clean up afterward:

```bash
kubectl --context kcd-lab delete namespace falco-demo
```

## Tearing down

```bash
minikube delete -p kcd-lab
rm -f terraform.tfstate terraform.tfstate.backup
```

Terraform's state tracks the cluster by ID; deleting the cluster out from under Terraform (rather than `terraform destroy`) is intentional here, `terraform destroy` against a cluster that's already gone or drifted tends to hang or fail partway through. Clearing state and starting over is more reliable for a lab environment than reconciling drift.

## Troubleshooting

**`apiserver`/pods healthy, but everything inside the cluster times out reaching anything (ClusterIPs, other pods, DNS)**
Seen during testing with Kubernetes v1.35.1 on this minikube/docker-driver setup: the node boots with two bridge interfaces (`cni0` and `bridge`) both claiming the pod CIDR's gateway IP, breaking all pod networking. `kubernetes_version` is pinned to `v1.33.8` in `variables.tf` specifically to avoid this. If you override it, verify basic pod-to-pod connectivity before assuming anything else is broken:
```bash
kubectl run a --image=busybox:1.36 --restart=Never --command -- sleep 60
kubectl run b --image=busybox:1.36 --restart=Never --command -- nslookup kubernetes.default
kubectl logs b   # should resolve to the cluster's Service CIDR, not time out
```

**`Docker Desktop has only Nmb memory but you specified 6000mb`**
Lower `memory` in `main.tf`, or raise Docker Desktop's allocation (Settings → Resources → Memory).

**ArgoCD's `argocd-redis-secret-init` job fails with `BackoffLimitExceeded`**
In every case we hit this during testing, it was a symptom of the broken pod networking above (the job can't reach the in-cluster API to write its Secret), not a problem with ArgoCD itself. Fix the networking first; retrying the Helm install without fixing the root cause just reproduces the same failure.

**Batch 2 fails with an ArgoCD authentication error**
`argocd_password` in `terraform.tfvars` is still the placeholder, or doesn't match the current cluster. ArgoCD's initial admin secret is regenerated every time you recreate the cluster, re-fetch it (step 3) after any `minikube delete` + batch 1 cycle.

## Repository layout

```
main.tf, variables.tf, providers.tf, outputs.tf   # cluster + ArgoCD (batch 1)
gatekeeper.tf, falco.tf                           # ArgoCD Applications (batch 2)
modules/argocd/                                   # ArgoCD Helm install
modules/argocd-helm-app/                          # reusable ArgoCD Application module
gatekeeper-policies/                              # templates, constraints, mutations (kubectl, not ArgoCD)
tests/                                             # Gatekeeper test Pods, Falco triggers
```
