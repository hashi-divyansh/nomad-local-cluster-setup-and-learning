.PHONY: provision terraform-init terraform-apply inventory ansible destroy

provision: terraform-init terraform-apply inventory ansible

terraform-init:
	terraform init

terraform-apply:
	terraform apply -auto-approve

inventory:
	python3 ansible/inventory/generate_inventory.py

ansible: inventory
	ANSIBLE_CONFIG=ansible/ansible.cfg ANSIBLE_ROLES_PATH=ansible/roles ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/site.yml

destroy:
	terraform destroy -auto-approve
