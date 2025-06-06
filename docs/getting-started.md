# Getting Started

This guide will help you start using InvokeHub in minutes.

## 📋 Prerequisites

- PowerShell 5.1 or higher (built into Windows 10/11)
- Internet connection  
- API key from your administrator

## 🚀 Quick Start

### 1. Start InvokeHub

The easiest way to start InvokeHub:

```powershell
# With API key
irm "https://your-invokehub.azurewebsites.net/api/loader?key=YOUR-KEY" | iex

# Without key (will prompt for authentication)
irm https://your-invokehub.azurewebsites.net/api/loader | iex
```

### 2. First Time Usage

When you run InvokeHub for the first time, you'll be prompted for authentication:

```powershell
# API Key method
Start-InvokeHub -ApiUrl "https://your-api.com/api" -ApiKey "your-key"

# Password method  
Start-InvokeHub -ApiUrl "https://your-api.com/api" -UsePassword
# You'll be prompted for the password
```

### 3. Navigate the Menu

After starting, you'll see the main menu:

```
InvokeHub v1.0
===============
Script Management Platform

Repository: 15 Scripts

📁 Administration
  [1] Update-ADUsers.ps1 (12.3 KB)
  [2] Reset-Passwords.ps1 (8.7 KB)

📁 Utilities  
  [3] Get-SystemInfo.ps1 (5.1 KB)

[S] Search | [F] Filter | [H] Help | [Q] Quit

Selection: _
```

### 4. Basic Commands

| Key | Action |
|-----|--------|
| `1-9` | Select script by number |
| `S` | Search for scripts |
| `F` | Filter by folder |
| `H` | Show help |
| `Q` | Quit |

### 5. Working with Scripts

Select a script by number to see options:

```
Deploy-WebApp.ps1
=================

[1] Execute
[2] Download  
[3] View Content
[4] Copy to Clipboard
[0] Back

Action: _
```

## 📖 Common Tasks

### Execute a Script

1. Select a script from the menu
2. Press `1` to execute
3. Confirm when prompted
4. Script runs in isolated scope

**Security tip**: Always review scripts before executing (press `3` to view content)

### Search for Scripts

Press `S` from the main menu:

```powershell
Search: *deploy*
# Shows all scripts with "deploy" in name or metadata
```

Use `*` as wildcard for flexible searching.

### Download Scripts

1. Select a script
2. Press `2` for download
3. Choose save location (default: Desktop)
4. Script is saved locally

### View Script Content

1. Select a script
2. Press `3` to view
3. Script shown with syntax highlighting
4. Press Enter to see more (pagination)

## 🎯 Usage Examples

### Run a specific script quickly
```powershell
# Start InvokeHub
$api = "https://your-invokehub.azurewebsites.net/api"
. (irm "$api/client")
Start-InvokeHub -ApiUrl $api -ApiKey "YOUR-KEY"

# Navigate to your script and execute
```

### Use in automation
```powershell
# Download a script directly (if you know the path)
$headers = @{ "X-API-Key" = "YOUR-KEY" }
$script = Invoke-RestMethod `
    -Uri "https://your-api/script?path=Utilities/Get-SystemInfo.ps1" `
    -Headers $headers

# Execute it
Invoke-Expression $script.content
```

### Create an alias
Add to your PowerShell profile:
```powershell
function hub {
    irm "https://your-invokehub.azurewebsites.net/api/loader?key=YOUR-KEY" | iex
}
```

Now just type `hub` to start!

## 🛡️ Security Best Practices

1. **Review before executing**: Always check script content (option 3) before running
2. **Know your scripts**: Only run scripts from trusted sources
3. **Check the hash**: Verify script hash when prompted
4. **Use least privilege**: Don't run PowerShell as admin unless necessary

## ❓ Troubleshooting

### InvokeHub won't start
```powershell
# Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Check PowerShell version
$PSVersionTable.PSVersion  # Should be 5.1+
```

### Authentication errors
- Verify your API key is correct
- Check for extra spaces or quotes
- Ensure internet connectivity

### Scripts not showing
- Contact your administrator
- Scripts may not be uploaded yet
- Check if you have the correct API endpoint

## 📚 Next Steps

- [PowerShell Client Guide](client-guide.md) - Advanced client features
- [API Reference](api-reference.md) - Use the API directly
- [FAQ](faq.md) - Frequently asked questions
- [Troubleshooting](troubleshooting.md) - Detailed problem solutions

## 💬 Getting Help

- 📧 Contact your InvokeHub administrator
- 💬 [GitHub Discussions](https://github.com/bdrogja/InvokeHub/discussions)
- 🐛 [Report Issues](https://github.com/bdrogja/InvokeHub/issues)