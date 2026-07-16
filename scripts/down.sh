#!/usr/bin/env bash
# Tear down the whole lab.
set -euo pipefail
CLUSTER="nginx-kind"
echo ">> deleting kind cluster '$CLUSTER' ..."
kind delete cluster --name "$CLUSTER"
echo ">> done. (terraform state is local; run 'rm -f terraform/terraform.tfstate*' to reset it)"
