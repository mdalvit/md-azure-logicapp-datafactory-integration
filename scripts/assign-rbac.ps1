#Requires -Version 7.0

<#
.SYNOPSIS
    Assigns RBAC role for Logic App to access Data Factory
.DESCRIPTION
    This script assigns the Data Factory Contributor role to a Logic App's managed identity
.PARAMETER LogicAppName
    Name of the Logic App
.PARAMETER ResourceGroupName
    Resource group containing the Logic App
.PARAMETER DataFactoryName
    Name of the Data Factory
.PARAMETER DataFactoryResourceGroup
    Resource group containing the Data Factory (defaults to same as Logic App)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$LogicAppName,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$DataFactoryName,
    
    [Parameter(Mandatory = $false)]
    [string]$DataFactoryResourceGroup = $ResourceGroupName
)

Write-Host "`n🔐 RBAC Role Assignment Script" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════`n" -ForegroundColor Cyan

try {
    # Get Logic App's managed identity principal ID
    Write-Host "📋 Getting Logic App managed identity..." -ForegroundColor Yellow
    $principalId = az logicapp show `
        --name $LogicAppName `
        --resource-group $ResourceGroupName `
        --query "identity.principalId" `
        --output tsv

    if ([string]::IsNullOrWhiteSpace($principalId)) {
        Write-Host "❌ Error: Could not retrieve managed identity. Ensure the Logic App has system-assigned identity enabled." -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ Principal ID: $principalId`n" -ForegroundColor Green

    # Get subscription ID
    $subscriptionId = az account show --query "id" --output tsv

    # Build scope
    $scope = "/subscriptions/$subscriptionId/resourceGroups/$DataFactoryResourceGroup/providers/Microsoft.DataFactory/factories/$DataFactoryName"

    Write-Host "🎯 Assigning role..." -ForegroundColor Yellow
    Write-Host "   Assignee: $principalId" -ForegroundColor White
    Write-Host "   Role: Data Factory Contributor" -ForegroundColor White
    Write-Host "   Scope: $scope`n" -ForegroundColor White

    # Assign role
    az role assignment create `
        --assignee $principalId `
        --role "Data Factory Contributor" `
        --scope $scope `
        --output none

    Write-Host "✅ Role assigned successfully!" -ForegroundColor Green
    Write-Host "`n⏳ Note: Role propagation may take up to 5 minutes`n" -ForegroundColor Yellow

} catch {
    Write-Host "`n❌ Failed to assign role!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
