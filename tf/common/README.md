# Common Module

This modules is responsible for deploying the common resources required for the reference archicture for Terraform on Azure.
- Resource Group (name speficied)
- Container Registry (name speficied)
- Key Vault (name speficied)


The module is saved in its own repository [here](https://github.com/jeffan18/terraform-azure-ref-common-module).


# Usage
## find the tenant_id:
```bash
az account list
```

## Fill environment variables and run script:

```bash
export TF_VAR_location="eastus"
export TF_VAR_tenant_id="e0d97d0a-f46f-4a90-aeed-9b8331...."
```

## init terraform and backend storage
```bash
./init.sh

terraform apply -auto-approve
```
