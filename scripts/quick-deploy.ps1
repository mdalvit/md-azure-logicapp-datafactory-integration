#Requires -Version 7.0

<#
.SYNOPSIS
    Quick deployment script for Logic App + Data Factory integration
.DESCRIPTION
    This script deploys a Logic App with Managed Identity and assigns the necessary RBAC role
    to trigger Azure Data Factory pipelines.
.PARAMETER ResourceGroupName
    Name of the resource group (will be created if doesn't exist)
.PARAMETER Location
    Azure region for deployment
.PARAMETER LogicAppName
    Name for the Logic App
.PARAMETER DataFactoryName
    Name of the existing Data Factory
.PARAMETER PipelineName
    Name of the default pipeline to trigger
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [string]$LogicAppName,
    
    [Parameter(Mandatory = $false)]
    [string]$DataFactoryName,
    
    [Parameter(Mandatory = $false)]
    [string]$PipelineName = "YourPipelineName"
)

# Function to prompt for input if not provided
function Get-ParameterValue {
    param(
        [string]$ParameterName,
        [string]$CurrentValue,
        [string]$PromptMessage
    )
    
    if ([string]::IsNullOrWhiteSpace($CurrentValue)) {
        return Read-Host -Prompt $PromptMessage
    }
    return $CurrentValue
}

Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Logic App + Data Factory Integration Deployment       ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Collect parameters interactively if not provided
$ResourceGroupName = Get-ParameterValue -ParameterName "ResourceGroupName" -CurrentValue $ResourceGroupName -PromptMessage "Enter Resource Group name"
$Location = Get-ParameterValue -ParameterName "Location" -CurrentValue $Location -PromptMessage "Enter Azure region (e.g., eastus, westeurope)"
$LogicAppName = Get-ParameterValue -ParameterName "LogicAppName" -CurrentValue $LogicAppName -PromptMessage "Enter Logic App name"
$DataFactoryName = Get-ParameterValue -ParameterName "DataFactoryName" -CurrentValue $DataFactoryName -PromptMessage "Enter Data Factory name"
$PipelineName = Get-ParameterValue -ParameterName "PipelineName" -CurrentValue $PipelineName -PromptMessage "Enter default pipeline name"

Write-Host "`n📋 Deployment Configuration:" -ForegroundColor Yellow
Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "   Location: $Location" -ForegroundColor White
Write-Host "   Logic App: $LogicAppName" -ForegroundColor White
Write-Host "   Data Factory: $DataFactoryName" -ForegroundColor White
Write-Host "   Pipeline: $PipelineName`n" -ForegroundColor White

$confirmation = Read-Host "Continue with deployment? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit
}

try {
    # Check if logged in to Azure
    Write-Host "`n🔐 Checking Azure login status..." -ForegroundColor Cyan
    $context = az account show 2>$null | ConvertFrom-Json
    if (-not $context) {
        Write-Host "❌ Not logged in to Azure. Please run 'az login' first." -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Logged in as: $($context.user.name)" -ForegroundColor Green
    Write-Host "   Subscription: $($context.name) ($($context.id))" -ForegroundColor White

    # Create resource group if it doesn't exist
    Write-Host "`n📦 Checking resource group..." -ForegroundColor Cyan
    $rgExists = az group exists --name $ResourceGroupName
    if ($rgExists -eq 'false') {
        Write-Host "   Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
        az group create --name $ResourceGroupName --location $Location | Out-Null
        Write-Host "✅ Resource group created" -ForegroundColor Green
    } else {
        Write-Host "✅ Resource group exists" -ForegroundColor Green
    }

    # Deploy Bicep template
    Write-Host "`n🚀 Deploying Logic App..." -ForegroundColor Cyan
    $deploymentName = "logicapp-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    $deployment = az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --template-file "../infrastructure/deploy-logicapp.bicep" `
        --parameters logicAppName=$LogicAppName `
                     location=$Location `
                     dataFactoryName=$DataFactoryName `
                     defaultPipelineName=$PipelineName `
        --query "properties.outputs" `
        --output json | ConvertFrom-Json

    Write-Host "✅ Logic App deployed successfully" -ForegroundColor Green

    # Extract outputs
    $principalId = $deployment.managedIdentityPrincipalId.value
    $callbackUrl = $deployment.logicAppCallbackUrl.value

    Write-Host "`n🔑 Managed Identity Principal ID: $principalId" -ForegroundColor White

    # Assign RBAC role
    Write-Host "`n🔐 Assigning RBAC role..." -ForegroundColor Cyan
    $subscriptionId = $context.id
    $scope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DataFactory/factories/$DataFactoryName"

    az role assignment create `
        --assignee $principalId `
        --role "Data Factory Contributor" `
        --scope $scope `
        --output none

    Write-Host "✅ RBAC role assigned: Data Factory Contributor" -ForegroundColor Green

    # Wait for role propagation
    Write-Host "`n⏳ Waiting for role assignment to propagate (30 seconds)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    # Save callback URL
    $callbackUrl | Out-File -FilePath "logic-app-callback-url.txt" -Encoding UTF8
    Write-Host "✅ Callback URL saved to: logic-app-callback-url.txt" -ForegroundColor Green

    # Success summary
    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║              🎉 DEPLOYMENT SUCCESSFUL! 🎉                ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green

    Write-Host "`n📊 Deployment Summary:" -ForegroundColor White
    Write-Host "   ✅ Logic App: $LogicAppName (Created)" -ForegroundColor Green
    Write-Host "   ✅ Managed Identity: Enabled" -ForegroundColor Green
    Write-Host "   ✅ RBAC Role: Data Factory Contributor (Assigned)" -ForegroundColor Green
    Write-Host "   ✅ Callback URL: Saved to file" -ForegroundColor Green

    Write-Host "`n🧪 Test your Logic App:" -ForegroundColor Cyan
    Write-Host "   Invoke-RestMethod -Uri '$callbackUrl' -Method Post -Body '{}' -ContentType 'application/json'" -ForegroundColor White

    Write-Host "`n📚 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Test the Logic App using the command above" -ForegroundColor White
    Write-Host "   2. Check Azure Portal for pipeline execution" -ForegroundColor White
    Write-Host "   3. Review Logic App run history for details" -ForegroundColor White
    Write-Host "   4. Update workflow parameters as needed`n" -ForegroundColor White

} catch {
    Write-Host "`n❌ Deployment failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
