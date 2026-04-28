.PHONY: provision terraform-init terraform-apply inventory ansible serve-binary autoscaler-job load-test destroy

HEY_FLAGS ?= -z 5m -c 200 -q 100

provision: terraform-init terraform-apply inventory ansible

terraform-init:
	terraform init

terraform-apply:
	terraform apply -auto-approve

inventory:
	python3 ansible/inventory/generate_inventory.py

ansible: inventory
	@set -a; \
	if [ -f .env ]; then . ./.env; fi; \
	set +a; \
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
	hey $(HEY_FLAGS) "$(WEBAPP_URL)"

serve-binary:
	@echo "Serving bin/ at http://host.orb.internal:8888 — press Ctrl+C to stop"
	python3 -m http.server 8888

autoscaler-job:
	NOMAD_ADDR=http://server-vm-0.orb.local:4646 nomad job run jobs/autoscaler.nomad.hcl

destroy:
	terraform destroy -auto-approv