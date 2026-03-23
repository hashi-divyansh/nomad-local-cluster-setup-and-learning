.PHONY: provision terraform-init terraform-apply inventory ansible load-test destroy

HEY_FLAGS ?= -z 5m -c 200 -q 100
ANSIBLE_EXTRA_ARGS ?=

provision: terraform-init terraform-apply inventory ansible

terraform-init:
	terraform init

terraform-apply:
	terraform apply -auto-approve

inventory:
	python3 ansible/inventory/generate_inventory.py

ansible: inventory
	@set -eu; \
	dd_api_key="$${DD_API_KEY:-$${DATADOG_API_KEY:-}}"; \
	dd_app_key="$${DD_APP_KEY:-$${DATADOG_APP_KEY:-}}"; \
	if [ -f ansible/group_vars/all/vault.yml ]; then \
		echo "Using ansible/group_vars/all/vault.yml for Datadog credentials."; \
		ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_ROLES_PATH=ansible/roles ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml $(ANSIBLE_EXTRA_ARGS); \
	else \
		if [ -z "$$dd_api_key" ] && [ -t 0 ]; then \
			printf "Enter Datadog API key: "; stty -echo; read -r dd_api_key; stty echo; printf "\n"; \
		fi; \
		if [ -z "$$dd_app_key" ] && [ -t 0 ]; then \
			printf "Enter Datadog APP key: "; stty -echo; read -r dd_app_key; stty echo; printf "\n"; \
		fi; \
		if [ -z "$$dd_api_key" ] || [ -z "$$dd_app_key" ]; then \
			echo "Datadog credentials are required. Set DD_API_KEY/DD_APP_KEY, or create ansible/group_vars/all/vault.yml."; \
			exit 1; \
		fi; \
		DD_API_KEY="$$dd_api_key" DD_APP_KEY="$$dd_app_key" ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_ROLES_PATH=ansible/roles ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml $(ANSIBLE_EXTRA_ARGS); \
	fi

load-test:
	@if ! command -v hey >/dev/null 2>&1; then \
		echo "hey is not installed. Install with: brew install hey"; \
		exit 1; \
	fi
	@if [ -z "$(WEBAPP_URL)" ]; then \
		echo "Set WEBAPP_URL to the webapp allocation URL"; \
		echo "Example: make load-test WEBAPP_URL=http://192.168.139.200:8080/"; \
		exit 1; \
	fi
	hey $(HEY_FLAGS) "$(WEBAPP_URL)"

destroy:
	terraform destroy -auto-approv