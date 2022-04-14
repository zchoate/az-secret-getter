#!/bin/bash

# Argument 1: the path to the file you want to write, required
# Argument 2: the name of the key vault, optional

az login --identity

if [ -z "$2" ]
    then
        # Get resource group of VM
        resource_group=$(curl -s http://169.254.169.254/metadata/instance?api-version=2021-12-13 -H metadata:true | jq '.compute.resourceGroupName' -r)
        # Look up key vault name in resource group
        key_vault=$(az keyvault list --resource-group ${resource_group} --query '[].name' -o tsv)
    else
        key_vault=$2
fi

secrets=$(az keyvault secret list --vault-name ${key_vault} --query "[?tags.deploy=='true'].name" -o tsv)
for secret in $secrets
do
    key=$(az keyvault secret show --vault-name ${key_vault} --name ${secret} --query 'tags.key' -o tsv)
    value=$(az keyvault secret show --vault-name ${key_vault} --name ${secret} --query 'value' -o tsv)
    echo "${key}=${value}" >> $1
done