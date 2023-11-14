#!make
-include .env
export

deploy:
	./scripts/deploy.sh

uninstall:
	./scripts/uninstall_all_deployments.sh

fmt:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform fmt --recursive

init:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform init -reconfigure \
	--backend-config="key=terraform.$$ENV.state"

init-upgrade:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform init -upgrade \
	--backend-config="key=terraform.$$ENV.state"

# How to use
# IMPORT_ARGUMENT=module.foo.bar some_resource make import
import:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform import $$IMPORT_ARGUMENT

workspace-list:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform workspace list

workspace-select:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform workspace select $$ENV || \
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform workspace new $$ENV

validate:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform validate

plan-out:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform plan -no-color > $$ENV.tfplan

plan:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform plan

refresh:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform refresh

output:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform output -json

apply:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform apply
	./scripts/publish_terraform_outputs.sh

state-list:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform state list

show:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform show -no-color

destroy:
	aws-vault exec $$AWS_VAULT_PROFILE -- terraform destroy

clean:
	rm -rf .terraform/ terraform.tfstate*

tfenv:
	tfenv use $(cat versions.tf 2> /dev/null | grep required_version | cut -d "\"" -f 2 | cut -d " " -f 2) && tfenv pin

generate_diagrams:
	docker run -it --rm -v "${PWD}":/app/ -w /app/documentation/diagrams/ mjdk/diagrams scripts/architecture_diagram.py
	docker run -it --rm -v "${PWD}":/app/ -w /app/documentation/diagrams/ mjdk/diagrams scripts/detailed_eks_diagram.py

.PHONY:
	fmt init workspace-list workspace-select validate plan-out plan \
	refresh output apply state-list show destroy clean tfenv
