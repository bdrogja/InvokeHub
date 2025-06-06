# Troubleshooting Guide

Solutions to common InvokeHub issues.

## 🔍 Diagnostic Tools

### Check Service Health
```powershell
# Basic health check
Invoke-RestMethod https://your-api/health

# Verbose check
Invoke-RestMethod https://your-api/health -Verbose
```

### Test Authentication
```powershell
$headers = @{ "X-API-Key" = "your-key" }
try {
    $result = Invoke-RestMethod https://your-api/auth -Method POST -Headers $headers
    Write-Host "✅ Authentication successful" -ForegroundColor Green
} catch {
    Write-Host "❌ Authentication failed: $_" -ForegroundColor Red
}
```

## 🚨 Common Issues

### "401 Unauthorized" Error

**Symptoms:**
- API calls return 401
- "Unauthorized" message

**Solutions:**

1. **Check API key format**
   ```powershell
   # Ensure no extra spaces or quotes
   $headers = @{ "X-API-Key" = "your-key-here" }  # ✅ Correct
   $headers = @{ "X-API-Key" = "'your-key-here'" }  # ❌ Wrong
   ```

2. **Verify key in Azure**
   ```bash
   az functionapp config appsettings list \
     --name invokehub-api \
     --resource-group rg-invokehub \
     --query "[?name=='API_KEY'].value" -o tsv
   ```

3. **Test with curl**
   ```bash
   curl -H "X-API-Key: your-key" https://your-api/menu -v
   ```

### "429 Too Many Requests" Error

**Symptoms:**
- Requests blocked after multiple calls
- Rate limit message

**Solutions:**

1. **Wait before retrying**
   ```powershell
   Start-Sleep -Seconds 2
   ```

2. **Increase rate limit**
   ```bash
   az functionapp config appsettings set \
     --name invokehub-api \
     --settings "RATE_LIMIT_SECONDS=0"  # Disable for testing
   ```

### Client Won't Start

**Symptoms:**
- Loader script fails
- "Cannot connect" errors

**Solutions:**

1. **Enable TLS 1.2**
   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   ```

2. **Check PowerShell version**
   ```powershell
   $PSVersionTable.PSVersion
   # Should be 5.1 or higher
   ```

3. **Test manually**
   ```powershell
   # Download client first
   Invoke-RestMethod https://your-api/client -OutFile test.ps1
   # Check if file downloaded
   Get-Content test.ps1 | Select-Object -First 10
   ```

### Scripts Not Showing in Menu

**Symptoms:**
- Empty menu
- Missing scripts

**Solutions:**

1. **Verify container exists**
   ```bash
   az storage container list \
     --account-name yourstorage \
     --query "[?name=='powershell-scripts']"
   ```

2. **Check container name**
   ```bash
   az functionapp config appsettings list \
     --name invokehub-api \
     --query "[?name=='BlobContainerName'].value" -o tsv
   ```

3. **List blobs**
   ```bash
   az storage blob list \
     --container-name powershell-scripts \
     --account-name yourstorage \
     --query "[].name"
   ```

### Script Execution Fails

**Symptoms:**
- Scripts won't run
- Syntax errors

**Solutions:**

1. **Check script encoding**
   - Save as UTF-8
   - No BOM (Byte Order Mark)

2. **Validate locally first**
   ```powershell
   # Test script syntax
   $script = Get-Content ./script.ps1 -Raw
   $null = [scriptblock]::Create($script)  # Throws if syntax error
   ```

3. **Check for blocked commands**
   - Remove dangerous commands
   - Avoid `Remove-Item -Recurse -Force`

### Function App Crashes/Restarts

**Symptoms:**
- Intermittent failures
- "Service Unavailable"

**Solutions:**

1. **Check logs**
   ```bash
   az functionapp log tail \
     --name invokehub-api \
     --resource-group rg-invokehub
   ```

2. **Review Application Insights**
   - Azure Portal → Function App → Failures
   - Check exception details

3. **Increase memory/timeout**
   ```json
   // host.json
   {
     "functionTimeout": "00:10:00"
   }
   ```

## 🔧 Advanced Diagnostics

### Enable Detailed Logging

```bash
# Set log level to Debug
az functionapp config appsettings set \
  --name invokehub-api \
  --settings "AzureFunctionsJobHost__logging__logLevel__default=Debug"
```

### Check Storage Connection

```powershell
# Test storage access
$connectionString = "your-connection-string"
$ctx = New-AzStorageContext -ConnectionString $connectionString
Get-AzStorageContainer -Context $ctx
```

### Network Issues

```powershell
# Test DNS resolution
Resolve-DnsName your-api.azurewebsites.net

# Test connectivity
Test-NetConnection your-api.azurewebsites.net -Port 443

# Trace route
tracert your-api.azurewebsites.net
```

## 📋 Debug Checklist

When issues occur, check:

### Configuration
- [ ] API_KEY is set correctly
- [ ] Storage connection string is valid
- [ ] Container name matches
- [ ] Function App is running

### Network
- [ ] HTTPS is working
- [ ] No firewall blocking
- [ ] DNS resolves correctly
- [ ] TLS 1.2 enabled

### Scripts
- [ ] Files have .ps1 extension
- [ ] UTF-8 encoding
- [ ] No syntax errors
- [ ] No dangerous commands

### Client
- [ ] PowerShell 5.1+
- [ ] Internet connection
- [ ] Correct API URL
- [ ] Valid API key

## 🆘 Getting Help

### Collect Information

Before asking for help, gather:

```powershell
# System info
$PSVersionTable

# Test results
Invoke-RestMethod https://your-api/health

# Error details
$Error[0] | Format-List -Force
```

### Where to Get Help

1. **GitHub Issues**: [Report bugs](https://github.com/yourusername/invokehub/issues)
2. **Discussions**: [Ask questions](https://github.com/yourusername/invokehub/discussions)
3. **Email**: support@example.com

### Provide Details

Include in your report:
- InvokeHub version
- PowerShell version
- Error messages
- Steps to reproduce
- What you've tried

## 💡 Prevention Tips

1. **Test locally first** before deploying
2. **Monitor regularly** with Application Insights
3. **Keep scripts simple** and well-tested
4. **Document changes** for easy rollback
5. **Regular backups** of scripts and config

## 📖 See Also

- [Configuration Guide](configuration.md)
- [Security Guide](security.md)
- [API Reference](api-reference.md)