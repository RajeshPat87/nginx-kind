SHELL := /bin/bash
CLUSTER := nginx-kind
TF := terraform -chdir=terraform

.DEFAULT_GOAL := help
.PHONY: help up cluster infra config test monitoring grafana install-ansible status down clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

up: cluster infra config ## Full bring-up: kind + terraform + ansible (no monitoring)
	@echo ">> lab is up. Run 'make test' to exercise all scenarios."

cluster: ## Create the kind cluster (ports 80/443 mapped)
	./scripts/up.sh cluster

infra: ## terraform apply: ingress-nginx, postgres, demo apps
	./scripts/up.sh infra

config: ## ansible post-config: TLS, basic-auth, ingress rules, seed DB, smoke test
	./scripts/up.sh config

test: ## Run the full ingress scenario test suite
	./scripts/test-scenarios.sh

monitoring: ## Install lightweight kube-prometheus-stack (needs extra RAM)
	$(TF) apply -target=helm_release.monitoring -var enable_monitoring=true -auto-approve -input=false
	$(TF) apply -var enable_monitoring=true -auto-approve -input=false
	@echo ">> monitoring installed. Run 'make grafana' then open http://localhost:3000 (admin/admin)."

grafana: ## Port-forward Grafana to http://localhost:3000
	kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

install-ansible: ## Create .venv and install Ansible (no sudo)
	./scripts/install-ansible.sh

status: ## Show nodes, pods and ingresses
	@kubectl get nodes -o wide; echo; kubectl get pods -A; echo; kubectl -n apps get ingress

down: ## Delete the kind cluster
	./scripts/down.sh

clean: down ## Alias for down
