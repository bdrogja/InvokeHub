using System;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Azure.Storage.Blobs;
using Microsoft.Extensions.Logging;
using InvokeHub.Security;
using InvokeHub.Utilities;

namespace InvokeHub.Services
{
    public interface IScriptService
    {
        Task<object> GetScriptAsync(string scriptPath);
        string GetLoaderScript(string functionUrl, string providedKey);
        string GetClientScript();
    }

    public class ScriptService : IScriptService
    {
        private readonly ILogger<ScriptService> _logger;
        private readonly IPathValidator _pathValidator;
        private readonly IScriptValidator _scriptValidator;
        private readonly BlobServiceClient _blobServiceClient;
        private readonly string _containerName;

        public ScriptService(
            ILogger<ScriptService> logger,
            IPathValidator pathValidator,
            IScriptValidator scriptValidator)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _pathValidator = pathValidator ?? throw new ArgumentNullException(nameof(pathValidator));
            _scriptValidator = scriptValidator ?? throw new ArgumentNullException(nameof(scriptValidator));
            
            _blobServiceClient = new BlobServiceClient(Configuration.StorageConnectionString);
            _containerName = Configuration.ContainerName;
        }

        public async Task<object> GetScriptAsync(string scriptPath)
        {
            if (!_pathValidator.IsValidPath(scriptPath))
            {
                throw new ArgumentException("Invalid script path");
            }

            var containerClient = _blobServiceClient.GetBlobContainerClient(_containerName);
            var blobClient = containerClient.GetBlobClient(scriptPath);

            if (!await blobClient.ExistsAsync())
            {
                throw new FileNotFoundException($"Script not found: {scriptPath}");
            }

            var response = await blobClient.DownloadAsync();
            using var streamReader = new StreamReader(response.Value.Content);
            var content = await streamReader.ReadToEndAsync();

            if (!_scriptValidator.IsValidScript(content))
            {
                _logger.LogWarning("Invalid PowerShell script content in: {Path}", scriptPath);
                throw new InvalidOperationException("Invalid script content");
            }

            return new
            {
                path = scriptPath,
                content = content,
                lastModified = response.Value.Details.LastModified,
                metadata = response.Value.Details.Metadata,
                contentHash = HashingUtilities.ComputeHash(content)
            };
        }

        public string GetLoaderScript(string functionUrl, string providedKey)
        {
            // Sanitize input
            providedKey = Regex.Replace(providedKey, @"[^\w\-]", "");
            
            return $@"# InvokeHub Loader v{Configuration.Version}
$ErrorActionPreference = 'Stop'

Write-Host 'Lade InvokeHub...' -ForegroundColor Cyan

try {{
    # TLS 1.2 sicherstellen
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # API URL
    $apiUrl = '{functionUrl}/api'
    
    # Health Check mit Timeout
    try {{
        $health = Invoke-RestMethod -Uri ""$apiUrl/health"" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $usePassword = $health.authMode -eq 'password'
        Write-Host ""Platform: $($health.platform) v$($health.version)"" -ForegroundColor DarkGray
    }}
    catch {{
        Write-Host ""Warnung: Health-Check fehlgeschlagen. Verwende Standard-Modus."" -ForegroundColor Yellow
        $usePassword = $false
    }}
    
    # Client mit Retry-Logic herunterladen
    $retries = 3
    $client = $null
    
    while ($retries -gt 0 -and -not $client) {{
        try {{
            $client = Invoke-RestMethod -Uri ""$apiUrl/client"" -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            break
        }}
        catch {{
            $retries--
            if ($retries -eq 0) {{ throw }}
            Write-Host ""Download fehlgeschlagen, versuche erneut... ($retries Versuche übrig)"" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }}
    }}
    
    # Auto-Start deaktivieren und Client laden
    $client = $client -replace 'if \(\$MyInvocation[\s\S]*?Start-InvokeHub[^\}}]*\}}', '# Auto-Start disabled'
    
    # Client in isoliertem Scope laden
    $scriptBlock = [scriptblock]::Create($client)
    . $scriptBlock
    
    # Einmal starten mit richtigen Parametern
    if ('{providedKey}') {{
        Start-InvokeHub -ApiUrl ""$apiUrl"" -ApiKey '{providedKey}'
    }}
    elseif ($usePassword) {{
        Start-InvokeHub -ApiUrl ""$apiUrl"" -UsePassword
    }}
    else {{
        Start-InvokeHub -ApiUrl ""$apiUrl""
    }}
    
}} catch {{
    Write-Host ""Fehler: $_"" -ForegroundColor Red
    Write-Host """"
    Write-Host ""Troubleshooting:"" -ForegroundColor Yellow
    Write-Host ""  1. Stelle sicher, dass du mit dem Internet verbunden bist""
    Write-Host ""  2. Prüfe ob die API erreichbar ist: $apiUrl/health""
    Write-Host ""  3. Versuche es mit dem manuellen Download:""
    Write-Host """"
    Write-Host ""Manuelle Alternative:"" -ForegroundColor Yellow
    Write-Host ""  Invoke-RestMethod '$apiUrl/client' -OutFile InvokeHub.ps1""
    Write-Host ""  . ./InvokeHub.ps1""
    if ($usePassword) {{
        Write-Host ""  Start-InvokeHub -ApiUrl '$apiUrl' -UsePassword""
    }} else {{
        Write-Host ""  Start-InvokeHub -ApiUrl '$apiUrl' -ApiKey 'YOUR-KEY'""
    }}
}}";
        }

        public string GetClientScript()
        {
            // In Produktion: Aus eingebetteter Resource laden
            return ResourceHelper.LoadEmbeddedResource("Powershell.Client.ps1");
        }
    }
}