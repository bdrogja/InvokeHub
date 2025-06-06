# Development Guide

This guide covers setting up a development environment and deploying InvokeHub to Azure.

## 📋 Prerequisites

### Development Requirements
- [.NET 6 SDK](https://dotnet.microsoft.com/download/dotnet/6.0)
- [Azure Functions Core Tools v4](https://docs.microsoft.com/azure/azure-functions/functions-run-local)
- [Git](https://git-scm.com/)
- PowerShell 5.1+
- Visual Studio 2022 or VS Code (recommended)

### Deployment Requirements
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- Azure subscription
- PowerShell 5.1+

## 🛠️ Local Development Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/invokehub.git
cd invokehub
```

### 2. Setup Development Environment

Run the automated setup script:

```powershell
./scripts/setup-dev.ps1
```

Or set up manually:

```bash
# Copy settings template
cp local.settings.json.template local.settings.json

# Edit local.settings.json with your values

# Restore packages
dotnet restore

# Build project
dotnet build
```

### 3. Configure Local Storage

**Option A - Use Azurite (Recommended):**
```bash
# Install Azurite
npm install -g azurite

# Start Azurite
azurite --silent --location ./.azurite
```

**Option B - Use Real Azure Storage:**
- Create a storage account in Azure
- Update `AzureWebJobsStorage` in `local.settings.json` with connection string

### 4. Configure Local Settings

Edit `local.settings.json`:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",
    "API_KEY": "dev-test-key-12345",
    "BlobContainerName": "powershell-scripts",
    "MAX_SCRIPT_SIZE_KB": "1024",
    "RATE_LIMIT_SECONDS": "1"
  }
}
```

### 5. Start the Function App

```bash
# Start Azure Functions
func start

# You should see:
# Functions:
# GetMenu: [GET] http://localhost:7071/api/menu
# GetScript: [GET] http://localhost:7071/api/script
# ...
```

### 6. Test Local Development

```powershell
# Test health endpoint
Invoke-RestMethod http://localhost:7071/api/health

# Test with the client
irm http://localhost:7071/api/loader | iex
```

### 7. Upload Test Scripts

Create a test script in your blob container:
- Use Azure Storage Explorer
- Connect to Azurite or your Azure Storage
- Create container `powershell-scripts`
- Upload `.ps1` files

## 🚀 Azure Deployment

### Quick Deployment

Use the automated deployment script:

```powershell
# Basic deployment
./scripts/deploy.ps1 -ResourceGroupName "rg-invokehub" -Location "westeurope"

# With custom parameters
./scripts/deploy.ps1 `
    -ResourceGroupName "rg-invokehub-prod" `
    -Location "westeurope" `
    -FunctionAppName "my-invokehub" `
    -ApiKey "my-secure-key-here"
```

The script will:
- ✅ Create all Azure resources
- ✅ Configure settings
- ✅ Deploy the code
- ✅ Test the deployment
- ✅ Output connection details

### Manual Deployment Steps

If you prefer manual deployment:

#### 1. Create Azure Resources

```powershell
# Variables
$rg = "rg-invokehub"
$location = "westeurope"
$storage = "stinvokehub$(Get-Random -Maximum 9999)"
$functionApp = "invokehub-api"

# Create resource group
az group create --name $rg --location $location

# Create storage account
az storage account create `
    --name $storage `
    --resource-group $rg `
    --location $location `
    --sku Standard_LRS

# Create function app
az functionapp create `
    --name $functionApp `
    --resource-group $rg `
    --storage-account $storage `
    --consumption-plan-location $location `
    --runtime dotnet `
    --runtime-version 6 `
    --functions-version 4
```

#### 2. Configure App Settings

```powershell
# Generate secure API key
$apiKey = [System.Guid]::NewGuid().ToString()

# Configure settings
az functionapp config appsettings set `
    --name $functionApp `
    --resource-group $rg `
    --settings `
        "API_KEY=$apiKey" `
        "BlobContainerName=powershell-scripts" `
        "MAX_SCRIPT_SIZE_KB=1024"
```

#### 3. Deploy the Code

```powershell
# Build project
dotnet publish -c Release -o ./publish

# Create deployment package
Compress-Archive -Path ./publish/* -DestinationPath deploy.zip -Force

# Deploy to Azure
az functionapp deployment source config-zip `
    --resource-group $rg `
    --name $functionApp `
    --src deploy.zip
```

#### 4. Create Script Container

```powershell
# Get storage connection string
$connString = az storage account show-connection-string `
    --name $storage `
    --resource-group $rg `
    --query connectionString -o tsv

# Create container
az storage container create `
    --name "powershell-scripts" `
    --connection-string $connString
```

### Post-Deployment Tasks

#### Enable Application Insights
```powershell
# Create App Insights
az monitor app-insights component create `
    --app "$functionApp-insights" `
    --location $location `
    --resource-group $rg

# Connect to Function App
$key = az monitor app-insights component show `
    --app "$functionApp-insights" `
    --resource-group $rg `
    --query instrumentationKey -o tsv

az functionapp config appsettings set `
    --name $functionApp `
    --resource-group $rg `
    --settings "APPINSIGHTS_INSTRUMENTATIONKEY=$key"
```

#### Upload Scripts
```powershell
# Upload scripts to blob storage
az storage blob upload-batch `
    --destination "powershell-scripts" `
    --source "./my-scripts" `
    --pattern "*.ps1" `
    --connection-string $connString
```

### Verify Deployment

```powershell
# Check health
Invoke-RestMethod "https://$functionApp.azurewebsites.net/api/health"

# Test with client
irm "https://$functionApp.azurewebsites.net/api/loader?key=$apiKey" | iex
```

## 🔄 Updating Deployments

### Update Code Only
```powershell
# Rebuild and redeploy
dotnet publish -c Release -o ./publish
Compress-Archive -Path ./publish/* -DestinationPath deploy.zip -Force

az functionapp deployment source config-zip `
    --resource-group $rg `
    --name $functionApp `
    --src deploy.zip
```

### Update Configuration
```powershell
# Update settings
az functionapp config appsettings set `
    --name $functionApp `
    --resource-group $rg `
    --settings "NEW_SETTING=value"
```

## 🧪 Testing

### Run Unit Tests
```bash
# Run all tests
dotnet test

# Run with coverage
dotnet test /p:CollectCoverage=true
```

### Test Deployment
```powershell
./scripts/test-deployment.ps1 `
    -ApiUrl "https://your-api.azurewebsites.net/api" `
    -ApiKey "your-key"
```

## 📁 Project Structure

```
InvokeHub/
├── Api/              # HTTP endpoints
├── Services/         # Business logic
├── Security/         # Security components
├── Models/           # Data models
├── Utilities/        # Helper classes
├── PowerShell/       # Embedded PS scripts
├── Configuration.cs  # Central configuration
├── Startup.cs        # DI setup
├── host.json         # Azure Functions config
└── InvokeHub.csproj # Project file
```

## 💡 Development Tips

### Local Debugging
1. Set breakpoints in Visual Studio/VS Code
2. Press F5 to start debugging
3. Use Postman or curl to test endpoints

### Hot Reload
```bash
# Watch for changes
dotnet watch --project . run
```

### Logging
```csharp
_logger.LogInformation("Processing script: {Path}", scriptPath);
_logger.LogError(ex, "Error loading script");
```

### Testing Authentication Locally
```powershell
$headers = @{ "X-API-Key" = "dev-test-key-12345" }
Invoke-RestMethod http://localhost:7071/api/menu -Headers $headers
```

## 🛟 Troubleshooting Development

### Function App won't start
- Check if port 7071 is already in use
- Verify .NET 6 SDK is installed
- Ensure Azurite is running (if using local storage)

### Storage connection issues
- Verify connection string format
- Check if Azurite is running
- Ensure container exists

### Build errors
```bash
# Clean and rebuild
dotnet clean
dotnet restore
dotnet build
```

## 📚 Additional Resources

- [Azure Functions Documentation](https://docs.microsoft.com/azure/azure-functions/)
- [.NET 6 Documentation](https://docs.microsoft.com/dotnet/core/whats-new/dotnet-6)
- [Azure Storage Documentation](https://docs.microsoft.com/azure/storage/)

## 🤝 Contributing

See [Contributing Guide](../CONTRIBUTING.md) for:
- Code style guidelines
- Pull request process
- Testing requirements
- Branch naming conventions