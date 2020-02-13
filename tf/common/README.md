# Common Module

This modules is responsible for deploying the common stuff required for the reference archicture for Terraform on Azure.The module is developed in its own repository [here](https://github.com/jcorioland/terraform-azure-ref-common-module).


# Usage
find the tenant_id:
```bash
az account list


Fill environment variables and run script:

```bash
export TF_VAR_location="eastus"
export TF_VAR_tenant_id="e0d97d0a-f46f-4a90-aeed-9b8331...."

# init terraform and backend storage
./init.sh

terraform apply -auto-approve
```
