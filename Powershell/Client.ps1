# InvokeHub Client v1.0.0
# PowerShell Script Management Platform
# Optimized for Windows PowerShell 5.1+ and PowerShell Core 7+ (Windows/macOS/Linux)

function Start-InvokeHub {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$ApiUrl,  # No default value - must be provided by loader
        
        [Parameter(Position = 1)]
        [string]$ApiKey = '',
        
        [switch]$UsePassword,
        
        [int]$TimeoutSeconds = 30,
        
        [switch]$EnableDebug
    )

    # Validate ApiUrl is provided
    if ([string]::IsNullOrWhiteSpace($ApiUrl)) {
        Write-Host "Error: API URL is required." -ForegroundColor Red
        Write-Host "Please use the loader or provide the URL:" -ForegroundColor Yellow
        Write-Host "  Start-InvokeHub -ApiUrl 'https://your-api.azurewebsites.net/api'" -ForegroundColor Gray
        return
    }

    # Initialization
    $script:ApiUrl = $ApiUrl.TrimEnd('/')
    $script:Headers = @{}
    $script:Timeout = $TimeoutSeconds
    $script:DebugMode = $EnableDebug
    
    # PowerShell Version Check
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "Error: PowerShell 5.0 or higher required." -ForegroundColor Red
        Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        return
    }
    
    # Ensure TLS 1.2 (important for older Windows versions)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        Write-Host "Warning: Could not enable TLS 1.2." -ForegroundColor Yellow
    }
    
    # Show banner
    function Show-Banner {
        Clear-Host
        Write-Host ""
        Write-Host "  InvokeHub v1.0" -ForegroundColor Cyan
        Write-Host "  ===============" -ForegroundColor DarkGray
        Write-Host "  Script Management Platform" -ForegroundColor Gray
        if ($script:DebugMode) {
            Write-Host "  DEBUG MODE ACTIVE" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    # Secure input function
    function Read-SecureInput {
        param(
            [string]$Prompt,
            [switch]$AsPlainText
        )
        
        if ($AsPlainText) {
            return Read-Host $Prompt
        }
        
        $secure = Read-Host $Prompt -AsSecureString
        
        # Cross-platform secure string conversion
        try {
            # New method for .NET Core
            if ([System.Runtime.InteropServices.Marshal]::PtrToStringBSTR) {
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
                try {
                    return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
                }
                finally {
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
                }
            }
        }
        catch {
            # Fallback for older versions
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
            try {
                return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }
    }

    # API call with error handling
    function Invoke-ApiRequest {
        param(
            [string]$Endpoint,
            [string]$Method = 'GET',
            [hashtable]$Headers = @{},
            [object]$Body = $null
        )
        
        $uri = "$script:ApiUrl/$Endpoint"
        $params = @{
            Uri = $uri
            Method = $Method
            Headers = $Headers + $script:Headers
            UseBasicParsing = $true
            TimeoutSec = $script:Timeout
            ErrorAction = 'Stop'
        }
        
        if ($Body) {
            $params.Body = $Body | ConvertTo-Json -Depth 10
            $params.ContentType = 'application/json'
        }
        
        if ($script:DebugMode) {
            Write-Host "DEBUG: API Call to $uri" -ForegroundColor Gray
        }
        
        try {
            $response = Invoke-RestMethod @params
            return $response
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $statusDescription = $_.Exception.Response.StatusDescription
            
            if ($statusCode -eq 401) {
                throw "Authentication failed. Please check credentials."
            }
            elseif ($statusCode -eq 429) {
                throw "Too many requests. Please wait a moment."
            }
            elseif ($statusCode -eq 404) {
                throw "Endpoint not found: $Endpoint"
            }
            elseif ($statusCode -ge 500) {
                throw "Server error ($statusCode): $statusDescription"
            }
            else {
                throw "API error: $_"
            }
        }
    }

    # Authentication
    Show-Banner
    
    try {
        if ($UsePassword) {
            Write-Host "  Password Authentication" -ForegroundColor Yellow
            $password = Read-SecureInput -Prompt "  Password"
            $script:Headers = @{ 'X-API-Key' = $password }
        }
        elseif ($ApiKey) {
            $script:Headers = @{ 'X-API-Key' = $ApiKey }
        }
        else {
            Write-Host "  API Key Required" -ForegroundColor Yellow
            $key = Read-SecureInput -Prompt "  API Key"
            $script:Headers = @{ 'X-API-Key' = $key }
        }

        # Test authentication
        Write-Host ""
        Write-Host "  Connecting..." -ForegroundColor Gray
        
        $auth = Invoke-ApiRequest -Endpoint 'auth' -Method 'POST'
        
        if ($auth.authenticated) {
            Write-Host "  ✓ Successfully connected!" -ForegroundColor Green
            if ($auth.sessionToken) {
                $script:Headers['X-Session-Token'] = $auth.sessionToken
            }
            Start-Sleep -Milliseconds 500
        }
        else {
            throw "Authentication failed"
        }
    }
    catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
        return
    }

    # Main menu
    MainMenu
}

function MainMenu {
    while ($true) {
        try {
            Show-Banner
            
            # Load menu with error handling
            Write-Host "  Loading repository..." -ForegroundColor Gray
            $menu = Invoke-ApiRequest -Endpoint 'menu'
            
            # Collect scripts with improved performance
            $allScripts = [System.Collections.Generic.List[PSObject]]::new()
            CollectScripts -Node $menu -Scripts $allScripts
            
            if ($allScripts.Count -eq 0) {
                Write-Host "  ⚠ No scripts found in repository." -ForegroundColor Yellow
                Write-Host ""
                Read-Host "  Press Enter to exit"
                return
            }
            
            Write-Host "  Repository: $($allScripts.Count) Scripts" -ForegroundColor Yellow
            Write-Host ""
            
            # Display grouped by folder with pagination
            Show-ScriptMenu -Scripts $allScripts
            
            Write-Host ""
            Write-Host "  [S] Search | [F] Filter | [H] Help | [Q] Quit" -ForegroundColor Cyan
            Write-Host ""
            
            $choice = Read-Host "  Selection"
            
            switch -Regex ($choice) {
                '^[Qq]$' { 
                    Write-Host "`n  Goodbye!" -ForegroundColor Green
                    return 
                }
                '^[Hh]$' { ShowHelp }
                '^[Ss]$' { SearchScripts -Scripts $allScripts }
                '^[Ff]$' { FilterScripts -Scripts $allScripts }
                '^\d+$' {
                    $index = [int]$choice
                    if ($index -gt 0 -and $index -le $allScripts.Count) {
                        $selected = $allScripts[$index - 1]
                        ShowScriptActions -Script $selected
                    }
                    else {
                        Write-Host "  ⚠ Invalid selection" -ForegroundColor Yellow
                        Start-Sleep -Seconds 1
                    }
                }
                default {
                    Write-Host "  ⚠ Invalid input" -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
            }
        }
        catch {
            Write-Host "  Error: $_" -ForegroundColor Red
            Write-Host ""
            $retry = Read-Host "  Try again? (Y/N)"
            if ($retry -ne 'Y' -and $retry -ne 'y') {
                return
            }
        }
    }
}

function Show-ScriptMenu {
    param($Scripts)
    
    $grouped = $Scripts | Group-Object { 
        $path = Split-Path $_.FullPath -Parent
        if ([string]::IsNullOrEmpty($path)) { 'Root' } else { $path }
    }
    
    $maxItemsPerScreen = 20
    $currentIndex = 1
    
    foreach ($group in $grouped | Sort-Object Name) {
        if ($currentIndex -gt $maxItemsPerScreen) {
            Write-Host "  ... and $($Scripts.Count - $maxItemsPerScreen) more. Use [S]earch for more." -ForegroundColor Gray
            break
        }
        
        $folder = $group.Name
        Write-Host "  📁 $folder" -ForegroundColor Yellow
        
        foreach ($script in $group.Group | Sort-Object Name) {
            if ($currentIndex -gt $maxItemsPerScreen) { break }
            
            $size = [math]::Round($script.Size / 1KB, 1)
            $index = $Scripts.IndexOf($script) + 1
            Write-Host "    [$index] $($script.Name) ($size KB)" -ForegroundColor Green
            $currentIndex++
        }
        Write-Host ""
    }
}

function CollectScripts {
    param($Node, $Scripts, $Path = '')
    
    if ($null -eq $Node -or $null -eq $Node.Children) { return }
    
    foreach ($item in $Node.Children) {
        if ($item.Type -eq 'script') {
            $Scripts.Add([PSCustomObject]@{
                Name = $item.Name
                Path = $item.Path
                Size = $item.Size
                FullPath = if ($Path) { "$Path/$($item.Name)" } else { $item.Name }
                Metadata = $item.Metadata
                LastModified = $item.LastModified
            })
        }
        elseif ($item.Type -eq 'folder' -and $item.Children) {
            $newPath = if ($Path) { "$Path/$($item.Name)" } else { $item.Name }
            CollectScripts -Node $item -Scripts $Scripts -Path $newPath
        }
    }
}

function ShowScriptActions {
    param($Script)
    
    Clear-Host
    Write-Host ""
    Write-Host "  $($Script.Name)" -ForegroundColor Cyan
    Write-Host "  $('=' * $Script.Name.Length)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Path: $($Script.FullPath)" -ForegroundColor Gray
    Write-Host "  Size: $([math]::Round($Script.Size / 1KB, 1)) KB" -ForegroundColor Gray
    
    if ($Script.LastModified) {
        Write-Host "  Modified: $($Script.LastModified)" -ForegroundColor Gray
    }
    
    if ($Script.Metadata -and $Script.Metadata.Count -gt 0) {
        Write-Host "  Metadata:" -ForegroundColor Gray
        foreach ($key in $Script.Metadata.Keys) {
            Write-Host "    $key : $($Script.Metadata[$key])" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "  [1] Execute" -ForegroundColor Green
    Write-Host "  [2] Download" -ForegroundColor Yellow
    Write-Host "  [3] View Content" -ForegroundColor Cyan
    Write-Host "  [4] Copy to Clipboard" -ForegroundColor Magenta
    Write-Host "  [0] Back" -ForegroundColor Gray
    Write-Host ""
    
    $action = Read-Host "  Action"
    
    if ($action -in '1','2','3','4') {
        try {
            Write-Host ""
            Write-Host "  Loading script..." -ForegroundColor Gray
            
            $response = Invoke-ApiRequest -Endpoint "script?path=$([Uri]::EscapeDataString($Script.Path))"
            
            if ($null -eq $response -or $null -eq $response.content) {
                throw "Empty response from server"
            }
            
            switch ($action) {
                '1' { # Execute
                    Write-Host ""
                    Write-Host "  ⚠ WARNING: You are about to execute a script!" -ForegroundColor Yellow
                    Write-Host "  Only proceed if you trust the script." -ForegroundColor Yellow
                    Write-Host ""
                    
                    if ($response.contentHash) {
                        Write-Host "  Script hash: $($response.contentHash)" -ForegroundColor Gray
                    }
                    
                    $confirm = Read-Host "  Really execute script? (YES to confirm)"
                    if ($confirm -eq 'YES') {
                        Write-Host ""
                        Write-Host "  === Execution ===" -ForegroundColor Cyan
                        Write-Host ""
                        
                        try {
                            # Execute script in isolated scope
                            $scriptBlock = [scriptblock]::Create($response.content)
                            & $scriptBlock
                        }
                        catch {
                            Write-Host "  Script error: $_" -ForegroundColor Red
                        }
                        
                        Write-Host ""
                        Write-Host "  === End ===" -ForegroundColor Cyan
                    }
                    else {
                        Write-Host "  Execution cancelled." -ForegroundColor Yellow
                    }
                }
                '2' { # Download
                    $fileName = Split-Path $Script.Path -Leaf
                    $defaultPath = Join-Path ([Environment]::GetFolderPath('Desktop')) $fileName
                    
                    Write-Host "  Default location: $defaultPath" -ForegroundColor Gray
                    $savePath = Read-Host "  Save as (Enter for default)"
                    
                    if ([string]::IsNullOrWhiteSpace($savePath)) { 
                        $savePath = $defaultPath 
                    }
                    
                    try {
                        $response.content | Out-File -FilePath $savePath -Encoding UTF8 -Force
                        Write-Host "  ✓ Saved: $savePath" -ForegroundColor Green
                        
                        # Offer to open
                        $open = Read-Host "  Open file? (Y/N)"
                        if ($open -eq 'Y' -or $open -eq 'y') {
                            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                                Start-Process notepad.exe -ArgumentList $savePath
                            }
                            elseif ($IsMacOS) {
                                Start-Process open -ArgumentList $savePath
                            }
                            else {
                                Write-Host "  Please open the file manually." -ForegroundColor Yellow
                            }
                        }
                    }
                    catch {
                        Write-Host "  Error saving: $_" -ForegroundColor Red
                    }
                }
                '3' { # View
                    Write-Host ""
                    Write-Host "  === Content of $($Script.Name) ===" -ForegroundColor Cyan
                    Write-Host ""
                    
                    # Syntax highlighting for better readability
                    $lines = $response.content -split "`n"
                    $lineNumber = 1
                    
                    foreach ($line in $lines) {
                        # Simple syntax highlighting
                        if ($line -match '^\s*#') {
                            Write-Host ("${lineNumber}: " + $line) -ForegroundColor Green
                        }
                        elseif ($line -match '^\s*function\s+') {
                            Write-Host ("${lineNumber}: " + $line) -ForegroundColor Cyan
                        }
                        elseif ($line -match '\$\w+') {
                            Write-Host ("${lineNumber}: " + $line) -ForegroundColor Yellow
                        }
                        else {
                            Write-Host ("${lineNumber}: " + $line)
                        }
                        $lineNumber++
                        
                        # Pagination for long scripts
                        if ($lineNumber % 30 -eq 0) {
                            $cont = Read-Host "  --- Show more? (Enter/Q) ---"
                            if ($cont -eq 'Q' -or $cont -eq 'q') { break }
                        }
                    }
                    
                    Write-Host ""
                    Write-Host "  === End (${lineNumber} lines) ===" -ForegroundColor Cyan
                }
                '4' { # Copy to clipboard
                    try {
                        if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                            $response.content | Set-Clipboard
                            Write-Host "  ✓ Copied to clipboard!" -ForegroundColor Green
                        }
                        else {
                            Write-Host "  ⚠ Clipboard not available on this system." -ForegroundColor Yellow
                            Write-Host "  Use option [2] to save instead." -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-Host "  Error copying: $_" -ForegroundColor Red
                    }
                }
            }
        }
        catch {
            Write-Host "  Error: $_" -ForegroundColor Red
        }
        
        Write-Host ""
        Read-Host "  Press Enter to continue"
    }
}

function SearchScripts {
    param($Scripts)
    
    Clear-Host
    Write-Host ""
    Write-Host "  Search" -ForegroundColor Cyan
    Write-Host "  ======" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Tip: Use * as wildcard (e.g. *test*)" -ForegroundColor Gray
    Write-Host ""
    
    $search = Read-Host "  Search term"
    if ([string]::IsNullOrWhiteSpace($search)) { return }
    
    # Extended search
    $found = $Scripts | Where-Object { 
        $_.Name -like "*$search*" -or 
        $_.FullPath -like "*$search*" -or
        ($_.Metadata.description -and $_.Metadata.description -like "*$search*") -or
        ($_.Metadata.author -and $_.Metadata.author -like "*$search*")
    }
    
    if ($found) {
        Write-Host ""
        Write-Host "  Found: $($found.Count) result(s)" -ForegroundColor Green
        Write-Host ""
        
        $index = 1
        foreach ($item in $found | Sort-Object FullPath) {
            Write-Host "  [$index] $($item.FullPath)" -ForegroundColor Yellow
            if ($item.Metadata.description) {
                Write-Host "       $($item.Metadata.description)" -ForegroundColor Gray
            }
            $index++
        }
        
        Write-Host ""
        $selection = Read-Host "  Selection (number or Enter)"
        
        if ($selection -match '^\d+$') {
            $selectedIndex = [int]$selection - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $found.Count) {
                ShowScriptActions -Script $found[$selectedIndex]
            }
        }
    }
    else {
        Write-Host "  No results found for '$search'." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "  Press Enter to continue"
    }
}

function FilterScripts {
    param($Scripts)
    
    Clear-Host
    Write-Host ""
    Write-Host "  Filter" -ForegroundColor Cyan
    Write-Host "  ======" -ForegroundColor DarkGray
    Write-Host ""
    
    # Show available folders
    $folders = $Scripts | ForEach-Object { Split-Path $_.FullPath -Parent } | 
               Where-Object { $_ } | Select-Object -Unique | Sort-Object
    
    if ($folders) {
        Write-Host "  Available folders:" -ForegroundColor Yellow
        $index = 1
        foreach ($folder in $folders) {
            Write-Host "  [$index] $folder" -ForegroundColor Green
            $index++
        }
        
        Write-Host ""
        $selection = Read-Host "  Choose folder (number)"
        
        if ($selection -match '^\d+$') {
            $selectedIndex = [int]$selection - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $folders.Count) {
                $selectedFolder = $folders[$selectedIndex]
                $filtered = $Scripts | Where-Object { 
                    (Split-Path $_.FullPath -Parent) -eq $selectedFolder 
                }
                
                Write-Host ""
                Write-Host "  Scripts in '$selectedFolder':" -ForegroundColor Yellow
                Write-Host ""
                
                $index = 1
                foreach ($script in $filtered | Sort-Object Name) {
                    Write-Host "  [$index] $($script.Name)" -ForegroundColor Green
                    $index++
                }
                
                Write-Host ""
                $scriptSelection = Read-Host "  Choose script (number)"
                
                if ($scriptSelection -match '^\d+$') {
                    $scriptIndex = [int]$scriptSelection - 1
                    if ($scriptIndex -ge 0 -and $scriptIndex -lt $filtered.Count) {
                        ShowScriptActions -Script $filtered[$scriptIndex]
                    }
                }
            }
        }
    }
    else {
        Write-Host "  No folders found." -ForegroundColor Yellow
        Read-Host "  Press Enter to continue"
    }
}

function ShowHelp {
    Clear-Host
    Write-Host ""
    Write-Host "  InvokeHub Help" -ForegroundColor Cyan
    Write-Host "  ==============" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Navigation:" -ForegroundColor Yellow
    Write-Host "    - Enter number: Select script directly"
    Write-Host "    - [S]: Search scripts (name, path, metadata)"
    Write-Host "    - [F]: Filter by folder"
    Write-Host "    - [H]: Show this help"
    Write-Host "    - [Q]: Quit program"
    Write-Host ""
    Write-Host "  Script Actions:" -ForegroundColor Yellow
    Write-Host "    - [1]: Execute script (with security warning)"
    Write-Host "    - [2]: Download script"
    Write-Host "    - [3]: View script content"
    Write-Host "    - [4]: Copy to clipboard"
    Write-Host "    - [0]: Back to main menu"
    Write-Host ""
    Write-Host "  Security:" -ForegroundColor Red
    Write-Host "    - Only execute scripts from trusted sources"
    Write-Host "    - Review content before execution (option 3)"
    Write-Host "    - Scripts run in isolated scope"
    Write-Host ""
    Write-Host "  Tips:" -ForegroundColor Green
    Write-Host "    - Use wildcards (*) when searching"
    Write-Host "    - Scripts can contain metadata (author, description)"
    Write-Host "    - API supports password or API key authentication"
    Write-Host ""
    Write-Host "  About InvokeHub:" -ForegroundColor Cyan
    Write-Host "    InvokeHub is a secure platform for managing"
    Write-Host "    and executing PowerShell scripts."
    Write-Host "    Version: 1.0.0"
    Write-Host ""
    Read-Host "  Press Enter to continue"
}