.PHONY: provision terraform-init terraform-apply inventory ansible load-test destroy

HEY_FLAGS ?= -z 5m -c 200 -q 100
LB_BASTION ?= root@server-vm-0@orb
LB_LOCAL_PORT ?= 18080

provision: terraform-init terraform-apply inventory ansible

terraform-init:
	terraform init

terraform-apply:
	terraform apply -auto-approve

inventory:
	python3 ansible/inventory/generate_inventory.py

ansible: inventory
	ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_ROLES_PATH=ansible/roles ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml

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
	@URL="$(WEBAPP_URL)"; \
	if curl -sS --connect-timeout 2 -o /dev/null "$$URL"; then \
		echo "Direct access reachable: $$URL"; \
		hey $(HEY_FLAGS) "$$URL"; \
	else \
		echo "Direct access failed for $$URL. Falling back to OrbStack SSH tunnel via $(LB_BASTION)."; \
		URL_NO_SCHEME="$${URL#http://}"; \
		URL_NO_SCHEME="$${URL_NO_SCHEME#https://}"; \
		HOSTPORT="$${URL_NO_SCHEME%%/*}"; \
		TARGET_HOST="$${HOSTPORT%:*}"; \
		TARGET_PORT="$${HOSTPORT##*:}"; \
		if [ "$$TARGET_HOST" = "$$TARGET_PORT" ]; then TARGET_PORT=80; fi; \
		if [ -z "$$TARGET_HOST" ] || [ -z "$$TARGET_PORT" ]; then \
			echo "Unable to parse WEBAPP_URL: $$URL"; \
			exit 1; \
		fi; \
		TUNNEL_CMD="ssh -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -f -N -L $(LB_LOCAL_PORT):$$TARGET_HOST:$$TARGET_PORT $(LB_BASTION)"; \
		eval "$$TUNNEL_CMD"; \
		LOCAL_URL="http://127.0.0.1:$(LB_LOCAL_PORT)/"; \
		if ! curl -sS --connect-timeout 5 -o /dev/null "$$LOCAL_URL"; then \
			echo "Tunnel established but local endpoint is not reachable: $$LOCAL_URL"; \
			echo "Clean up any stale tunnel and retry:"; \
			echo "pkill -f 'ssh -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -f -N -L $(LB_LOCAL_PORT):$$TARGET_HOST:$$TARGET_PORT $(LB_BASTION)'"; \
			exit 1; \
		fi; \
		echo "Testing through tunnel endpoint: $$LOCAL_URL"; \
		hey $(HEY_FLAGS) "$$LOCAL_URL"; \
		pkill -f "ssh -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -f -N -L $(LB_LOCAL_PORT):$$TARGET_HOST:$$TARGET_PORT $(LB_BASTION)" >/dev/null 2>&1 || true; \
	fi

destroy:
	terraform destroy -auto-approv