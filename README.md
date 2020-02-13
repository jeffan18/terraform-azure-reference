# Deploy a two-tier reference application in 3 environments using Azure DevOps Pipeline and Terraform code
 

## Architecture Design

![Architecture Diagram](assets/architecture.jpg)

Environments
  There are 3 environments (Dev, UAT and Prod). 

Infrastrucuture Components:
  Each of the environment contains 2 tiers: App and DB.
  - An [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/intro-kubernetes) cluster, in its own virtual network
  - A backend virtual network, that contains one or more virtual machines that act as bastion / jump boxes
  - An [Azure Database for MySQL](https://docs.microsoft.com/en-us/azure/mysql/overview) service instance 
  - MYSQL is configured with [virtual network service endpoint](https://docs.microsoft.com/en-us/azure/mysql/concepts-data-access-and-security-vnet) so it can be reached by jumbbox and services running in AKS (Backend virtual network and AKS virtual network are peered together)

Common services for all environments:
- [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/), to store the Docker image
- [Azure KeyVault](https://docs.microsoft.com/en-us/azure/key-vault/), to store the application secrets securely
- [Azure Firewall](https://docs.microsoft.com/en-us/azure/firewall/), to protect the application

- Monitoring:
We use [Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/) with logs analytics to monitor all this infrastructure (and potentially the application).

## DevOps Practice

*Note: the focus is on deploying the infrastructure.*

- IaC: All the infrastructure components are defined using Terraform HCL manifests 
- Version Control: Terraform codes and related scripts are stored in GitHub (this repository) 
- CI/CD pipeline: use [Azure DevOps Pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/overview?view=azure-devops) to deploy all the infrastructure.
  *Note: The pipeline can be hosted in any other CI/CD tool, like Jenkins*

As you can see, some parts of the infrastructure are specific for each environment, some other will be shared. This will help to illustrate how to handle deployments of different resources having different lifecycle.

## Prerequisites before deployment

- A Microsoft Azure account, with subscriptions.
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- [Terraform executable](https://learn.hashicorp.com/terraform/getting-started/install.html) on a local machine.
- GitHub account (Fork this repository)
- An Azure DevOps organization. Setup Azure DevOps[instructions](https://azure.microsoft.com/en-us/services/devops/?nav=min)

   ***To solve: the credentials of Azure login info***

### Terraform State

- Terraform needs to maintain state between the deployments, for the infrastructure components that need be added or removed.
- Storing Terraform state remotely is a best practice to make sure you don't loose it across your different execution environment (from your machine to any CI/CD agent). 
- The best pratice is to use Azure Storage as a remote backend for Terraform state.

### Pre-works - create common RG, Backend Storage, and Key Vault
from Azure CLI:
 - az login

  - execute scripts: [scripts/init-remote-state-backend.sh](scripts/init-remote-state-backend.sh):

```bash
#!/bin/bash

set -e

. ./init-env-vars.sh

# Create the resource group
echo "Creating $COMMON_RESOURCE_GROUP_NAME resource group..."
az group create -n $COMMON_RESOURCE_GROUP_NAME -l $LOCATION

echo "Resource group $COMMON_RESOURCE_GROUP_NAME created."

# Create the storage account
echo "Creating $TF_STATE_STORAGE_ACCOUNT_NAME storage account..."
az storage account create -g $COMMON_RESOURCE_GROUP_NAME -l $LOCATION \
  --name $TF_STATE_STORAGE_ACCOUNT_NAME \
  --sku Standard_LRS \
  --encryption-services blob

echo "Storage account $TF_STATE_STORAGE_ACCOUNT_NAME created."

# Retrieve the storage account key
echo "Retrieving storage account key..."
ACCOUNT_KEY=$(az storage account keys list --resource-group $COMMON_RESOURCE_GROUP_NAME --account-name $TF_STATE_STORAGE_ACCOUNT_NAME --query [0].value -o tsv)

echo "Storage account key retrieved."

# Create a storage container (for the Terraform State)
echo "Creating $TF_STATE_CONTAINER_NAME storage container..."
az storage container create --name $TF_STATE_CONTAINER_NAME --account-name $TF_STATE_STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY

echo "Storage container $TF_STATE_CONTAINER_NAME created."

# Create an Azure KeyVault
echo "Creating $KEYVAULT_NAME key vault..."
az keyvault create -g $COMMON_RESOURCE_GROUP_NAME -l $LOCATION --name $KEYVAULT_NAME

echo "Key vault $KEYVAULT_NAME created."

# Storage the Terraform State Storage Key into KeyVault
echo "Storage storage access key into key vault secret..."
az keyvault secret set --name tfstate-storage-key --value $ACCOUNT_KEY --vault-name $KEYVAULT_NAME

echo "Key vault secret created."

# Display information
echo "Azure Storage Account and KeyVault have been created."
echo "Run the following command to initialize Terraform to store its state into Azure Storage:"
echo "terraform init -backend-config=\"storage_account_name=$TF_STATE_STORAGE_ACCOUNT_NAME\" -backend-config=\"container_name=$TF_STATE_CONTAINER_NAME\" -backend-config=\"access_key=\$(az keyvault secret show --name tfstate-storage-key --vault-name $KEYVAULT_NAME --query value -o tsv)\" -backend-config=\"key=terraform-ref-architecture-tfstate\""
```

This script is responsible for:
- Creating a common Azure Resource Group (shared for all environments)
- Creating an Azure Storage Account in this common RG
- Retrieving the Storage Account access key
- Creating a container in the Storage Account (where the Terraform state will be stored)
- Creating an Azure Key Vault in the common RG
- Storing the the Storage Account access key into a Key Vault secret named `tfstate-storage-key`

Once completed, the script will print the `terraform init` command line that can be used later to init Terraform to use this backend, like:

```bash
terraform init -backend-config="storage_account_name=$STORAGE_ACCOUNT_NAME" -backend-config="container_name=$CONTAINER_NAME" -backend-config="access_key=$(az keyvault secret show --name tfstate-storage-key --vault-name $KEYVAULT_NAME --query value -o tsv)" -backend-config="key=terraform-ref-architecture-tfstate"
```

*Note: If you are working with multiple cloud providers, you may not want to spare storage state into each provider. For this reason, you may want to look the [Terraform Cloud remote state management](https://www.hashicorp.com/blog/introducing-terraform-cloud-remote-state-management) that has been introduced by HashiCorp.*


## Terraform modules

### What are Terraform modules?

[Terraform modules](https://www.terraform.io/docs/modules/index.html) are used to group together a set of resources that have the same lifecycle. Modules is a convenient way for this deployment which has 3 environments and they have similar services and components in the design.

Here are some questions that you can ask yourself for before writing a module:
- Do have all the resources involved the same lifecycle?
  - Will the resources be deployed all together all the time?
  - Will the resources be updated all together all the time?
  - Will the resources be destroyed all together all the time?
- Is there multiple resources involved? If there is just one, the module is probably useless
- From an architectural/functionnal perspective, does it makes sense to group all these resources together? (network, compute, storage etc...)
- Does any of the resource involved depend from a resource that is not in this module?

If the answer to these questions is `no` most of the time, then you probably don't need to write a module.

Sometime, instead of writing a big module, it can be useful to write multiple ones and nest them together, depending on the scenario you want to cover.

You can read more about Terraform modules on [this page of the Terraform documentation](https://www.terraform.io/docs/modules/index.html).

### How to test Terraform modules?

Like every piece of code, Terraform modules can be tested. [Terratest](https://github.com/gruntwork-io/terratest) is the tool I have used to write the test of the modules available in this repository.

## Modules of this reference architecture 

This reference architecture uses different Terraform module to deploy different set of components and deal with their different lifecyle:

### Common Module 

It contains all the common resources like ACR, KeyVault...
This module is defined in its own [GitHub repository](https://github.com/jcorioland/terraform-azure-ref-common-module).
More documentation [here](tf/common/README.md).

### Core Environment Module

It contains the base components for an environment (resource group, network...).
More documentation [here](tf/core/README.md).

### Azure Kubernetes Service Module

It contains everything needed to deploy an Azure Kubernetes Service cluster inside a given environment.
It is defined in its own [GitHub repository](https://github.com/jcorioland/terraform-azure-ref-aks-module).
More documentation [here](tf/aks/README.md).
