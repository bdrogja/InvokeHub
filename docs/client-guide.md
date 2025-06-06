# PowerShell Client Guide

Complete guide to using the InvokeHub PowerShell client.

## 🚀 Starting the Client

### Basic Start
```powershell
# Start with API key
irm "https://your-api/loader?key=YOUR-KEY" | iex

# Interactive start (prompts for credentials)
irm https://your-api/loader | iex
```

### Advanced Start Options
```powershell
# With parameters
Start-InvokeHub -ApiUrl "https://your-api" -ApiKey "YOUR-KEY"

# With password authentication
Start-InvokeHub -ApiUrl "https://your-api" -UsePassword

# With debug mode
Start-InvokeHub -ApiUrl "https://your-api" -ApiKey "YOUR-KEY" -EnableDebug

# With custom timeout
Start-InvokeHub -ApiUrl "https://your-api" -ApiKey "YOUR-KEY" -TimeoutSeconds 60
```

## 📋 Main Menu

The main menu shows all available scripts organized by folders:

```
InvokeHub v1.0
===============
Script Management Platform

Repository: 42 Scripts

📁 Administration
  [1] Update-ADUsers.ps1 (12.3 KB)
  [2] Reset-Passwords.ps1 (8.7 KB)

📁 Deployment
  [3] Deploy-WebApp.ps1 (45.2 KB)
  
[S] Search | [F] Filter | [H] Help | [Q] Quit
```

### Navigation Keys

| Key | Function | Description |
|-----|----------|-------------|
| `1-99` | Select | Choose script by number |
| `S` | Search | Search scripts by name/metadata |
| `F` | Filter | Filter by folder |
| `H` | Help | Show help screen |
| `Q` | Quit | Exit InvokeHub |

## 🔍 Search Features

### Basic Search
- Press `S` from main menu
- Enter search term
- Use `*` as wildcard

### Search Examples
```
test        # Find scripts containing "test"
*deploy*    # Find scripts with "deploy" anywhere
Get-*       # Find scripts starting with "Get-"
```

### Search Scope
The search looks in:
- Script names
- File paths
- Metadata descriptions
- Author information

## 📁 Filter by Folder

1. Press `F` from main menu
2. Select a folder from the list
3. View only scripts in that folder

## 📄 Script Actions

When you select a script, you get these options:

### 1. Execute Script
- Press `1`
- Review security warning
- Confirm execution
- Script runs in isolated scope

### 2. Download Script
- Press `2`
- Choose location (default: Desktop)
- File saved with original name

### 3. View Content
- Press `3`
- Shows script with syntax highlighting
- Line numbers included
- Press Enter to see more (pagination)

### 4. Copy to Clipboard
- Press `4`
- Full script copied to clipboard
- Windows only feature

## ⚙️ Advanced Features

### Debug Mode
Enable verbose logging:
```powershell
Start-InvokeHub -EnableDebug
```

Shows:
- API calls being made
- Response times
- Error details

### Custom Timeout
For slow connections:
```powershell
Start-InvokeHub -TimeoutSeconds 60
```

### Session Management
The client maintains your session:
- Auto-refreshes authentication
- Remembers your API URL
- Handles reconnection

## 🎨 Customization

### Create a Wrapper Function
```powershell
function Start-MyHub {
    $apiUrl = "https://mycompany-invokehub.azurewebsites.net/api"
    $apiKey = $env:INVOKEHUB_API_KEY
    
    if (-not $apiKey) {
        Write-Error "Please set INVOKEHUB_API_KEY environment variable"
        return
    }
    
    . (irm "$apiUrl/client")
    Start-InvokeHub -ApiUrl $apiUrl -ApiKey $apiKey
}
```

### Add to PowerShell Profile
```powershell
# Add to $PROFILE
function hub {
    Start-MyHub
}
```

Now just type `hub` to start!

## 🌐 Platform Support

### Windows PowerShell 5.1+
- Full feature support
- Clipboard functionality
- TLS 1.2 auto-enabled

### PowerShell Core 7+ (Windows/macOS/Linux)
- Cross-platform support
- Some features may vary
- No clipboard on non-Windows

## ⚡ Performance Tips

1. **Large Repositories**
   - Use search instead of scrolling
   - Filter by folder for faster navigation

2. **Slow Connections**
   - Increase timeout setting
   - Client caches menu structure

3. **Script Execution**
   - Preview large scripts first
   - Download and run locally for better performance

## 🛡️ Security Features

- **Confirmation Prompts**: Before executing any script
- **Hash Display**: Shows script hash for verification
- **Isolated Execution**: Scripts run in separate scope
- **Path Validation**: Prevents directory traversal
- **Rate Limiting**: Protects against abuse

## 🔧 Troubleshooting

### Client won't start
```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Enable TLS 1.2 manually
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### Authentication issues
```powershell
# Test API directly
$headers = @{ "X-API-Key" = "YOUR-KEY" }
Invoke-RestMethod "https://your-api/health" -Headers $headers
```

### See Also
- [Getting Started](getting-started.md) - Quick start guide
- [API Reference](api-reference.md) - Direct API usage
- [Troubleshooting](troubleshooting.md) - More solutions