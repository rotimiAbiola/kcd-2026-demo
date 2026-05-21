#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:-argocd.minikube.local}"
PROFILE="${2:-tf-test-cluster}"

if ! command -v minikube >/dev/null 2>&1; then
  echo "Error: minikube is not installed or not in PATH." >&2
  exit 1
fi

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  echo "Error: minikube profile '$PROFILE' is not running or does not exist." >&2
  echo "Start it with: minikube start -p $PROFILE" >&2
  exit 1
fi

IP="$(minikube ip -p "$PROFILE")"
if [[ -z "$IP" ]]; then
  echo "Error: unable to get IP for profile '$PROFILE'." >&2
  exit 1
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

# Remove any existing mapping for the hostname, then append the latest IP mapping.
awk -v host="$HOSTNAME" '
{
  for (i = 2; i <= NF; i++) {
    if ($i == host) {
      skip = 1
      break
    }
  }
  if (!skip) {
    print
  }
  skip = 0
}
' /etc/hosts > "$TMP_FILE"

echo "$IP $HOSTNAME" >> "$TMP_FILE"

sudo cp "$TMP_FILE" /etc/hosts

echo "Updated /etc/hosts: $HOSTNAME -> $IP (profile: $PROFILE)"
