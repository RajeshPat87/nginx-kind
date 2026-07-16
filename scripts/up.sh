#!/usr/bin/env bash
# Bring-up helper. Sub-commands: cluster | infra | config | all
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="nginx-kind"
CMD="${1:-all}"

ensure_cluster() {
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    echo ">> kind cluster '$CLUSTER' already exists."
  else
    echo ">> creating kind cluster '$CLUSTER' ..."
    kind create cluster --config "$REPO/kind/cluster.yaml" --wait 180s
  fi
  kubectl config use-context "kind-${CLUSTER}" >/dev/null
  kubectl cluster-info --context "kind-${CLUSTER}" | head -1
}

run_infra() {
  echo ">> terraform apply (ingress-nginx, postgres, demo apps) ..."
  terraform -chdir="$REPO/terraform" init -upgrade -input=false
  terraform -chdir="$REPO/terraform" apply -auto-approve -input=false
}

ansible_bin() {
  if [ -x "$REPO/.venv/bin/ansible-playbook" ]; then
    echo "$REPO/.venv/bin/ansible-playbook"
  elif command -v ansible-playbook >/dev/null 2>&1; then
    command -v ansible-playbook
  else
    echo ""
  fi
}

run_config() {
  local ap
  ap="$(ansible_bin)"
  if [ -z "$ap" ]; then
    echo "!! ansible-playbook not found. Run: ./scripts/install-ansible.sh" >&2
    exit 1
  fi
  echo ">> ansible post-config using: $ap"
  ( cd "$REPO/ansible" && "$ap" site.yml )
}

case "$CMD" in
  cluster) ensure_cluster ;;
  infra)   run_infra ;;
  config)  run_config ;;
  all)     ensure_cluster; run_infra; run_config ;;
  *) echo "usage: $0 [cluster|infra|config|all]"; exit 1 ;;
esac
