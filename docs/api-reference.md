# API Reference

InvokeHub REST API documentation.

## 🌐 Base URL

```
https://your-invokehub.azurewebsites.net/api
```

## 🔐 Authentication

All endpoints except `/health` and `/loader` require authentication.

### Header
```
X-API-Key: your-api-key
```

### Example
```powershell
$headers = @{
    "X-API-Key" = "your-api-key"
}
Invoke-RestMethod "https://api/menu" -Headers $headers
```

## 📍 Endpoints

### GET /health
Health check endpoint - no authentication required.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0",
  "platform": "InvokeHub",
  "authMode": "apikey",
  "containerName": "powershell-scripts",
  "environment": "Production"
}
```

### POST /auth
Authenticate and receive session information.

**Request:**
```http
POST /api/auth
X-API-Key: your-api-key
```

**Response:**
```json
{
  "authenticated": true,
  "sessionToken": "...",
  "expiresIn": 3600,
  "authMode": "apikey"
}
```

### GET /menu
Get the complete script repository structure.

**Request:**
```http
GET /api/menu
X-API-Key: your-api-key
```

**Response:**
```json
{
  "name": "Root",
  "type": "folder",
  "path": "",
  "children": [
    {
      "name": "Administration",
      "type": "folder",
      "path": "Administration",
      "children": [
        {
          "name": "Update-ADUsers.ps1",
          "type": "script",
          "path": "Administration/Update-ADUsers.ps1",
          "size": 12543,
          "lastModified": "2024-01-15T14:32:00Z",
          "metadata": {
            "author": "Admin Team",
            "description": "Updates Active Directory users"
          }
        }
      ]
    }
  ]
}
```

### GET /script
Download a specific script.

**Request:**
```http
GET /api/script?path=Administration/Update-ADUsers.ps1
X-API-Key: your-api-key
```

**Response:**
```json
{
  "path": "Administration/Update-ADUsers.ps1",
  "content": "# PowerShell script content\n...",
  "lastModified": "2024-01-15T14:32:00Z",
  "contentHash": "SHA256Hash...",
  "metadata": {
    "author": "Admin Team",
    "description": "Updates Active Directory users"
  }
}
```

### GET /loader
Get the PowerShell loader script - no authentication required.

**Request:**
```http
GET /api/loader?key=optional-api-key
```

**Response:**
```powershell
# InvokeHub Loader v1.0.0
# ... loader script content ...
```

### GET /client
Get the full PowerShell client.

**Request:**
```http
GET /api/client
```

**Response:**
```powershell
# InvokeHub Client v1.0.0
# ... client script content ...
```

## 🔴 Error Responses

### Error Format
```json
{
  "error": "Error message description"
}
```

### Status Codes

| Code | Description | Example |
|------|-------------|---------|
| 400 | Bad Request | Invalid script path |
| 401 | Unauthorized | Missing or invalid API key |
| 404 | Not Found | Script not found |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Server Error | Internal error |

## 📚 Examples

### PowerShell Examples

#### Get all scripts
```powershell
$headers = @{ "X-API-Key" = "your-key" }
$menu = Invoke-RestMethod "https://api/menu" -Headers $headers
```

#### Download a specific script
```powershell
$headers = @{ "X-API-Key" = "your-key" }
$script = Invoke-RestMethod `
    -Uri "https://api/script?path=Utilities/Get-Info.ps1" `
    -Headers $headers

# Execute the script
Invoke-Expression $script.content
```

#### Search for scripts
```powershell
# Get menu and filter
$menu = Invoke-RestMethod "https://api/menu" -Headers $headers
$scripts = $menu.children | Where-Object { $_.name -like "*deploy*" }
```

### cURL Examples

#### Health check
```bash
curl https://your-api/health
```

#### Get menu
```bash
curl -H "X-API-Key: your-key" https://your-api/menu
```

#### Download script
```bash
curl -H "X-API-Key: your-key" \
  "https://your-api/script?path=Scripts/test.ps1" \
  -o test.ps1
```

### Python Example

```python
import requests

api_url = "https://your-api"
headers = {"X-API-Key": "your-key"}

# Get menu
response = requests.get(f"{api_url}/menu", headers=headers)
menu = response.json()

# Download script
script_path = "Utilities/Get-Info.ps1"
response = requests.get(
    f"{api_url}/script",
    params={"path": script_path},
    headers=headers
)
script = response.json()
print(script["content"])
```

## 🔒 Security Notes

1. **Always use HTTPS** in production
2. **Keep API keys secure** - never commit to source control
3. **Rate limiting** is enforced - respect it
4. **Path validation** prevents directory traversal
5. **Script validation** blocks dangerous commands

## 📖 See Also

- [Getting Started](getting-started.md)
- [Configuration Guide](configuration.md)
- [Security Guide](security.md)
- [Troubleshooting](troubleshooting.md)