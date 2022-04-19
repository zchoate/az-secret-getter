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
.NOTES
Author: Zachary Choate
#>

#Requires -Modules Az.Accounts, Az.KeyVault

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$filePath,
    [Parameter(Mandatory=$false)]
    [string]$keyVault
)

Connect-AzAccount -Identity

if ( -not $keyVault) {
    $resourceGroup = (Invoke-RestMethod -Method GET -Headers @{ "metadata"=$true } -Uri "http://169.254.169.254/metadata/instance?api-version=2021-12-13").compute.resourceGroupName
    $keyVault = (Get-AzKeyVault -ResourceGroupName $resourceGroup).vaultName
}

$secrets = Get-AzKeyVaultSecret -VaultName $keyVault | Where-Object {$_.Tags.deploy -eq 'true' }
foreach ($secret in $secrets) {
    $key = $secret.Tags.key
    $value = Get-AzKeyVaultSecret -VaultName $keyVault -Name $secret.Name -AsPlainText
    "$key=$value" >> $filePath
}