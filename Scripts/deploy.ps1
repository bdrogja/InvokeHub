#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys InvokeHub to Azure with all required resources.

.DESCRIPTION
    This script automates the complete deployment of InvokeHub including:
    - Resource Group creation
    - Storage Account with container
    - Application Insights
    - Function App with configuration
    - Optional: Upload sample scripts

.PARAMETER ResourceGroupName
    Name of the Azure Resource Group (default: rg-invokehub-prod)

.PARAMETER Location
    Azure region for deployment (default: westeurope)

.PARAMETER FunctionAppName
    Name of the Function App (default: auto-generated unique name)

.PARAMETER ApiKey
    API key for authentication (default: auto-generated secure key)

.PARAMETER UseExistingStorage
    Use existing storage account instead of creating new

.PARAMETER SkipDeploy
    Only create resources, skip code deployment

.PARAMETER UploadSamples
    Upload sample PowerShell scripts after deployment

.EXAMPLE
    ./deploy.ps1 -ResourceGroupName "rg-invokehub" -Location "westeurope"

.EXAMPLE
    ./deploy.ps1 -FunctionAppName "invokehub-prod" -ApiKey $env:INVOKEHUB_KEY -UploadSamples

.NOTES
    Author: InvokeHub Team
    Requires: Azure CLI, .NET 6 SDK
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ResourceGroupName = "rg-invokehub-prod",
    
    [Parameter()]
    [string]$Location = "westeurope",
    
    [Parameter()]
    [string]$FunctionAppName = "",
    
    [Parameter()]
    [string]$ApiKey = "",
    
    [Parameter()]
    [switch]$UseExistingStorage,
    
    [Parameter()]
    [switch]$SkipDeploy,
    
    [Parameter()]
    [switch]$UploadSamples,
    
    [Parameter()]
    [string]$StorageAccountName = "",
    
    [Parameter()]
    [string]$ContainerName = "powershell-scripts"
)

# Script configuration
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

# Colors for output
function Write-Step { Write-Host "`n==> $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }

# Banner
Write-Host @"
`n
  ___                 _        _   _       _     
 |_ _|_ ____   _____ | | _____| | | |_   _| |__  
  | || '_ \ \ / / _ \| |/ / _ \ |_| | | | | '_ \ 
  | || | | \ V / (_) |   <  __/  _  | |_| | |_) |
 |___|_| |_|\_/ \___/|_|\_\___|_| |_|\__,_|_.__/ 
                                                  
  Azure Deployment Script v1.0
  
"@ -ForegroundColor Cyan

# Validate prerequisites
Write-Step "Checking prerequisites..."

# Check Azure CLI
try {
    $azVersion = az version --query '"azure-cli"' -o tsv
    Write-Success "Azure CLI found: $azVersion"
} catch {
    Write-Error "Azure CLI not found. Please install from: https://aka.ms/installazurecli"
    exit 1
}

# Check .NET SDK
try {
    $dotnetVersion = dotnet --version
    Write-Success ".NET SDK found: $dotnetVersion"
} catch {
    Write-Error ".NET SDK 6.0+ required. Download from: https://dotnet.microsoft.com/download"
    exit 1
}

# Check Azure login
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Warning "Not logged in to Azure"
    Write-Host "Please login to continue..." -ForegroundColor Yellow
    az login
    $account = az account show | ConvertFrom-Json
}
Write-Success "Logged in as: $($account.user.name)"
Write-Success "Subscription: $($account.name)"

# Generate unique names if not provided
if (-not $FunctionAppName) {
    $FunctionAppName = "invokehub-$(Get-Random -Maximum 9999)"
    Write-Warning "Generated Function App name: $FunctionAppName"
}

if (-not $StorageAccountName) {
    $StorageAccountName = "stinvokehub$(Get-Random -Maximum 9999)"
    Write-Warning "Generated Storage Account name: $StorageAccountName"
}

# Generate secure API key if not provided
if (-not $ApiKey) {
    Add-Type -AssemblyName System.Web
    $ApiKey = [System.Web.Security.Membership]::GeneratePassword(32, 8)
    Write-Warning "Generated API key (save this!): $ApiKey"
}

# Create Resource Group
Write-Step "Creating Resource Group '$ResourceGroupName' in '$Location'..."
az group create `
    --name $ResourceGroupName `
    --location $Location `
    --output none

Write-Success "Resource Group created"

# Create Storage Account (if not using existing)
if (-not $UseExistingStorage) {
    Write-Step "Creating Storage Account '$StorageAccountName'..."
    
    az storage account create `
        --name $StorageAccountName `
        --resource-group $ResourceGroupName `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 `
        --https-only true `
        --min-tls-version TLS1_2 `
        --output none
    
    Write-Success "Storage Account created"
    
    # Get connection string
    $storageConnection = az storage account show-connection-string `
        --name $StorageAccountName `
        --resource-group $ResourceGroupName `
        --query connectionString `
        --output tsv
    
    # Create container
    Write-Step "Creating blob container '$ContainerName'..."
    az storage container create `
        --name $ContainerName `
        --connection-string $storageConnection `
        --public-access off `
        --output none
    
    Write-Success "Container created"
} else {
    Write-Step "Using existing Storage Account..."
    $storageConnection = az storage account show-connection-string `
        --name $StorageAccountName `
        --resource-group $ResourceGroupName `
        --query connectionString `
        --output tsv
}

# Create Application Insights
Write-Step "Creating Application Insights..."
$appInsightsName = "$FunctionAppName-insights"

az monitor app-insights component create `
    --app $appInsightsName `
    --location $Location `
    --resource-group $ResourceGroupName `
    --application-type web `
    --output none

$instrumentationKey = az monitor app-insights component show `
    --app $appInsightsName `
    --resource-group $ResourceGroupName `
    --query instrumentationKey `
    --output tsv

Write-Success "Application Insights created"

# Create Function App
Write-Step "Creating Function App '$FunctionAppName'..."

az functionapp create `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --storage-account $StorageAccountName `
    --consumption-plan-location $Location `
    --runtime dotnet `
    --runtime-version 6 `
    --functions-version 4 `
    --app-insights-key $instrumentationKey `
    --output none

Write-Success "Function App created"

# Configure App Settings
Write-Step "Configuring Function App settings..."

$settings = @(
    "API_KEY=$ApiKey",
    "BlobContainerName=$ContainerName",
    "PRODUCTION_API_URL=https://$FunctionAppName.azurewebsites.net/api",
    "REQUIRE_SIGNED_SCRIPTS=false",
    "MAX_SCRIPT_SIZE_KB=1024",
    "RATE_LIMIT_SECONDS=1",
    "CACHE_CONTROL_SECONDS=300"
)

az functionapp config appsettings set `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --settings $settings `
    --output none

Write-Success "App settings configured"

# Deploy code (unless skipped)
if (-not $SkipDeploy) {
    Write-Step "Building and deploying application..."
    
    # Build
    Write-Host "Building project..." -ForegroundColor Gray
    dotnet publish -c Release -o ./publish
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed"
        exit 1
    }
    
    # Create deployment package
    Write-Host "Creating deployment package..." -ForegroundColor Gray
    Push-Location ./publish
    Compress-Archive -Path * -DestinationPath ../deploy.zip -Force
    Pop-Location
    
    # Deploy
    Write-Host "Deploying to Azure..." -ForegroundColor Gray
    az functionapp deployment source config-zip `
        --resource-group $ResourceGroupName `
        --name $FunctionAppName `
        --src ./deploy.zip `
        --output none
    
    Write-Success "Deployment completed"
    
    # Cleanup
    Remove-Item ./deploy.zip -Force
}

# Upload sample scripts (if requested)
if ($UploadSamples) {
    Write-Step "Uploading sample scripts..."
    
    $samplePath = "./examples/sample-scripts"
    if (Test-Path $samplePath) {
        az storage blob upload-batch `
            --destination $ContainerName `
            --source $samplePath `
            --connection-string $storageConnection `
            --pattern "*.ps1" `
            --output none
        
        Write-Success "Sample scripts uploaded"
    } else {
        Write-Warning "Sample scripts folder not found: $samplePath"
    }
}

# Test deployment
Write-Step "Testing deployment..."

$healthUrl = "https://$FunctionAppName.azurewebsites.net/api/health"
Write-Host "Waiting for Function App to start..." -ForegroundColor Gray

$attempts = 0
$maxAttempts = 30
$success = $false

while ($attempts -lt $maxAttempts -and -not $success) {
    try {
        $response = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 5
        if ($response.status -eq "healthy") {
            $success = $true
        }
    } catch {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
        $attempts++
    }
}

if ($success) {
    Write-Success "Health check passed!"
    Write-Host "Platform: $($response.platform) v$($response.version)" -ForegroundColor Gray
} else {
    Write-Warning "Health check timed out (app may still be starting)"
}

# Summary
Write-Host "`n`n" -NoNewline
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green

Write-Host "`nResources created:" -ForegroundColor Cyan
Write-Host "  Resource Group:  $ResourceGroupName" -ForegroundColor White
Write-Host "  Function App:    $FunctionAppName" -ForegroundColor White
Write-Host "  Storage Account: $StorageAccountName" -ForegroundColor White
Write-Host "  Container:       $ContainerName" -ForegroundColor White
Write-Host "  App Insights:    $appInsightsName" -ForegroundColor White

Write-Host "`nURLs:" -ForegroundColor Cyan
Write-Host "  API Base:    https://$FunctionAppName.azurewebsites.net/api" -ForegroundColor White
Write-Host "  Health:      https://$FunctionAppName.azurewebsites.net/api/health" -ForegroundColor White
Write-Host "  Loader:      https://$FunctionAppName.azurewebsites.net/api/loader" -ForegroundColor White

Write-Host "`nAuthentication:" -ForegroundColor Cyan
Write-Host "  API Key:     $ApiKey" -ForegroundColor Yellow

Write-Host "`nQuick test:" -ForegroundColor Cyan
Write-Host "  irm `"https://$FunctionAppName.azurewebsites.net/api/loader?key=$ApiKey`" | iex" -ForegroundColor White

Write-Host "`nAzure Portal:" -ForegroundColor Cyan
Write-Host "  https://portal.azure.com/#resource/subscriptions/$($account.id)/resourceGroups/$ResourceGroupName" -ForegroundColor White

Write-Host "`n⚠  IMPORTANT: Save the API key above - it won't be shown again!" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# Save deployment info
$deploymentInfo = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ResourceGroup = $ResourceGroupName
    FunctionApp = $FunctionAppName
    StorageAccount = $StorageAccountName
    ApiUrl = "https://$FunctionAppName.azurewebsites.net/api"
    ApiKey = $ApiKey
}

$deploymentInfo | ConvertTo-Json | Out-File "./deployment-info.json"
Write-Success "Deployment info saved to: deployment-info.json"