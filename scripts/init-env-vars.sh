#!/bin/bash

set -e

export LOCATION=eastus
export COMMON_RESOURCE_GROUP_NAME=RG-Common-Resources
export TF_STATE_STORAGE_ACCOUNT_NAME=forterraformbackend
export TF_STATE_CONTAINER_NAME=tfstate
export KEYVAULT_NAME=Key-Vault-fan-eastus
