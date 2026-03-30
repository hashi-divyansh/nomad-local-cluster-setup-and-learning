.PHONY: provision terraform-init terraform-apply inventory ansible setup-datadog-creds load-test destroy

HEY_FLAGS ?= -z 5m -c 200 -q 100
ANSIBLE_EXTRA_ARGS ?=
DATADOG_ENV_FILE ?= .datadog.env

provision: terraform-init terraform-apply inventory ansible

terraform-init:
	terraform init

terraform-apply:
	terraform apply -auto-approve

inventory:
	python3 ansible/inventory/generate_inventory.py

ansible: inventory
	@set -eu; \
	if [ -f "$(DATADOG_ENV_FILE)" ]; then set -a; . "$(DATADOG_ENV_FILE)"; set +a; fi; \
	dd_api_key="$${DD_API_KEY:-$${DATADOG_API_KEY:-}}"; \
	dd_app_key="$${DD_APP_KEY:-$${DATADOG_APP_KEY:-}}"; \
	if [ ! -f ansible/group_vars/all/vault.yml ] && { [ -z "$$dd_api_key" ] || [ -z "$$dd_app_key" ]; }; then \
		if [ -t 0 ]; then \
			echo "Datadog credentials not found. Running one-time setup..."; \
			$(MAKE) --no-print-directory setup-datadog-creds; \
			set -a; . "$(DATADOG_ENV_FILE)"; set +a; \
			dd_api_key="$${DD_API_KEY:-$${DATADOG_API_KEY:-}}"; \
			dd_app_key="$${DD_APP_KEY:-$${DATADOG_APP_KEY:-}}"; \
		fi; \
	fi; \
	if [ -f ansible/group_vars/all/vault.yml ]; then \
		echo "Using ansible/group_vars/all/vault.yml for Datadog credentials."; \
		ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_ROLES_PATH=ansible/roles ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml $(ANSIBLE_EXTRA_ARGS); \
	else \
		if [ -z "$$dd_api_key" ] || [ -z "$$dd_app_key" ]; then \
			echo "Datadog credentials are required."; \
			echo "Run 'make setup-datadog-creds' once, or set DD_API_KEY/DD_APP_KEY, or use ansible/group_vars/all/vault.yml."; \
			exit 1; \
		fi; \
		DD_API_KEY="$$dd_api_key" DD_APP_KEY="$$dd_app_key" ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_ROLES_PATH=ansible/roles ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml $(ANSIBLE_EXTRA_ARGS); \
	fi

setup-datadog-creds:
	@set -eu; \
	printf "Enter Datadog API key: "; stty -echo; read -r dd_api_key; stty echo; printf "\n"; \
	printf "Enter Datadog APP key: "; stty -echo; read -r dd_app_key; stty echo; printf "\n"; \
	if [ -z "$$dd_api_key" ] || [ -z "$$dd_app_key" ]; then \
		echo "Both Datadog API and APP keys are required."; \
		exit 1; \
	fi; \
	umask 077; \
	{ \
		printf 'DD_API_KEY=%s\n' "$$dd_api_key"; \
		printf 'DD_APP_KEY=%s\n' "$$dd_app_key"; \
	} > "$(DATADOG_ENV_FILE)"; \
	echo "Saved Datadog credentials to $(DATADOG_ENV_FILE) (mode 600)."

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