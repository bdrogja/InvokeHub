# Configuration Guide

Configure InvokeHub for your environment.

## 📋 Environment Variables

InvokeHub uses environment variables for configuration. In Azure, these are set as Application Settings.

### Required Settings

| Variable | Description | Example |
|----------|-------------|---------|
| `AzureWebJobsStorage` | Azure Storage connection string | `DefaultEndpointsProtocol=https;AccountName=...` |
| `API_KEY` or `API_PASSWORD` | Authentication method (one required) | `your-secure-key-here` |

### Optional Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `BlobContainerName` | Container for scripts | `powershell-scripts` |
| `REQUIRE_SIGNED_SCRIPTS` | Require script signatures | `false` |
| `MAX_SCRIPT_SIZE_KB` | Maximum script size | `1024` |
| `RATE_LIMIT_SECONDS` | Rate limit window | `1` |
| `CACHE_CONTROL_SECONDS` | Cache duration | `300` |

## 🔧 Local Development

### local.settings.json

For local development, create `local.settings.json`:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",
    "API_KEY": "dev-test-key-12345",
    "BlobContainerName": "powershell-scripts",
    "REQUIRE_SIGNED_SCRIPTS": "false",
    "MAX_SCRIPT_SIZE_KB": "1024",
    "RATE_LIMIT_SECONDS": "1"
  }
}
```

### Using Azurite

For local storage emulation:
```bash
# Install
npm install -g azurite

# Run
azurite --silent --location ./.azurite
```

## ☁️ Azure Configuration

### Set via Azure CLI

```bash
# Set single value
az functionapp config appsettings set \
  --name invokehub-api \
  --resource-group rg-invokehub \
  --settings "API_KEY=your-secure-key"

# Set multiple values
az functionapp config appsettings set \
  --name invokehub-api \
  --resource-group rg-invokehub \
  --settings "API_KEY=your-key" \
             "MAX_SCRIPT_SIZE_KB=2048" \
             "RATE_LIMIT_SECONDS=2"
```

### Set via Azure Portal

1. Navigate to your Function App
2. Go to **Configuration** → **Application settings**
3. Click **+ New application setting**
4. Add your key-value pairs
5. Click **Save** and **Continue**

## 🔐 Authentication Modes

### API Key Mode

Most common and simple:

```json
{
  "API_KEY": "your-secure-api-key-here"
}
```

- Generate a strong key (32+ characters)
- Rotate regularly
- One key for all users

### Password Mode

For user-friendly authentication:

```json
{
  "API_PASSWORD": "your-secure-password"
}
```

- Users enter password when prompted
- Good for interactive use
- Easier to remember than API keys

## 📦 Storage Configuration

### Container Structure

By default, scripts are organized in the blob container:

```
powershell-scripts/
├── Administration/
│   ├── Update-Users.ps1
│   └── Reset-Passwords.ps1
├── Deployment/
│   └── Deploy-App.ps1
└── Utilities/
    └── Get-Info.ps1
```

### Storage Account Settings

Recommended settings:
- **Replication**: LRS (Locally Redundant Storage) for cost efficiency
- **Performance**: Standard
- **Access tier**: Hot
- **Secure transfer**: Required
- **TLS version**: 1.2 minimum

## ⚡ Performance Tuning

### Script Size Limits

```json
{
  "MAX_SCRIPT_SIZE_KB": "2048"  // 2MB max
}
```

Adjust based on your largest scripts.

### Rate Limiting

```json
{
  "RATE_LIMIT_SECONDS": "1"  // 1 request per second
}
```

Increase for trusted environments:
- `0` = No rate limiting (not recommended)
- `1` = Default (1 request/second)
- `5` = Strict (1 request/5 seconds)

### Caching

```json
{
  "CACHE_CONTROL_SECONDS": "300"  // 5 minutes
}
```

Affects:
- Client script caching
- Menu structure caching

## 🛡️ Security Settings

### Require Signed Scripts

```json
{
  "REQUIRE_SIGNED_SCRIPTS": "true"
}
```

When enabled:
- Only signed PowerShell scripts are served
- Unsigned scripts are rejected
- Use for high-security environments

### IP Restrictions

Configure in Azure Portal:
1. Function App → **Networking**
2. **Access Restrictions**
3. Add IP rules

## 📊 Monitoring

### Application Insights

Automatically configured during deployment. To view:

1. Azure Portal → Function App
2. **Application Insights** → **View Application Insights data**

### Key Metrics to Monitor

- Request rate
- Failed requests
- Response time
- Authentication failures

## 🔄 Configuration Changes

### Apply Changes

Azure automatically restarts the Function App when settings change.

### Verify Changes

```powershell
# Check health endpoint
Invoke-RestMethod https://your-api/health
```

## 💡 Best Practices

1. **Never hardcode values** - Always use environment variables
2. **Use strong API keys** - Minimum 32 characters
3. **Rotate keys regularly** - Every 90 days
4. **Monitor usage** - Watch for unusual patterns
5. **Test locally first** - Use local.settings.json

## 📖 See Also

- [Security Guide](security.md)
- [Development Guide](development.md)
- [Troubleshooting](troubleshooting.md)