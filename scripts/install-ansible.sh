#!/usr/bin/env bash
# Install Ansible into a project-local virtualenv (no sudo, PEP 668 safe).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$REPO/.venv"

echo ">> creating venv at $VENV"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip >/dev/null
echo ">> installing ansible-core"
"$VENV/bin/pip" install "ansible-core>=2.16"

echo ">> ansible installed:"
"$VENV/bin/ansible-playbook" --version | head -1
echo ">> use it via 'make config' or: $VENV/bin/ansible-playbook -i ansible/inventory.ini ansible/site.yml"
