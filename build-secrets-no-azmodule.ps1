<#
.DESCRIPTION
- build a .env file using secrets obtained from Key Vault as the VM identity
- assumes there is only 1 key vault in the resource group if key vault parameter is not assigned
.PARAMETER filePath
- File path of .env or similar file including name of file
- Example: C:\data\.env
- Required
.PARAMETER keyVault
- Name of Key Vault
- Not required
.PARAMETER resourceGroup
- Name of Resource Group containing Key Vault
- Not required
.NOTES
Author: Zachary Choate
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$filePath,
    [Parameter(Mandatory=$false)]
    [string]$keyVault,
    [Parameter(Mandatory=$false)]
    [string]$resourceGroup
)

$token = (Invoke-RestMethod -Method GET -Headers @{ "metadata" = "true" } -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/").access_token

$metadata = (Invoke-RestMethod -Method GET -Headers @{ "metadata"=$true } -Uri "http://169.254.169.254/metadata/instance?api-version=2021-12-13").compute
$subscriptionId = $metadata.subscriptionId

if (( -not $keyVault) -and ( -not $resourceGroup)) {
    $resourceGroup = $metadata.resourceGroupName
    $keyVaultUri = (Invoke-RestMethod -Method GET -Headers @{ Authorization = "Bearer $token" } -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults?api-version=2021-10-01").value[0].properties.vaultUri
} elseif (( -not $keyVault) -and ($resourceGroup)) {
    $keyVaultUri = (Invoke-RestMethod -Method GET -Headers @{ Authorization = "Bearer $token" } -Uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults?api-version=2021-10-01").value[0].properties.vaultUri
} else {
    $keyVaultUri = ((Invoke-RestMethod -Method GET -Headers @{ Authorization = "Bearer $token" } -Uri "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.KeyVault/vaults?api-version=2021-10-01").value | Where-Object {$_.name -eq $keyVault}).properties.vaultUri
}

$keyVaultToken = (Invoke-RestMethod -Method GET -Headers @{ "metadata" = "true" } -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net").access_token

$secrets = (Invoke-RestMethod -Method GET -Headers @{ Authorization = "Bearer $keyVaultToken" } -Uri "$keyVaultUri/secrets?api-version=7.3").value | Where-Object {$_.tags.deploy -eq "true"}
foreach ($secret in $secrets) {
    $key = $secret.tags.key
    $value = (Invoke-RestMethod -Method GET -Headers @{ Authorization = "Bearer $keyVaultToken" } -Uri "$($secret.id)?api-version=7.3").value
    "$key=$value" >> $filePath
}