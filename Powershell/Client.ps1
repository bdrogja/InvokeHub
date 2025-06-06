# InvokeHub Client v1.0.0
# PowerShell Script Management Platform
# Optimiert für Windows PowerShell 5.1+ und PowerShell Core 7+ (Windows/macOS/Linux)

function Start-InvokeHub {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$ApiUrl = '',
        
        [Parameter(Position = 1)]
        [string]$ApiKey = '',
        
        [switch]$UsePassword,
        
        [int]$TimeoutSeconds = 30,
        
        [switch]$EnableDebug
    )

    # Initialisierung
    $script:ApiUrl = $ApiUrl.TrimEnd('/')
    $script:Headers = @{}
    $script:Timeout = $TimeoutSeconds
    $script:DebugMode = $EnableDebug
    
    # PowerShell Version Check
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "Fehler: PowerShell 5.0 oder höher erforderlich." -ForegroundColor Red
        Write-Host "Aktuelle Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        return
    }
    
    # TLS 1.2 sicherstellen (wichtig für ältere Windows-Versionen)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        Write-Host "Warnung: Konnte TLS 1.2 nicht aktivieren." -ForegroundColor Yellow
    }
    
    # Banner anzeigen
    function Show-Banner {
        Clear-Host
        Write-Host ""
        Write-Host "  InvokeHub v1.0" -ForegroundColor Cyan
        Write-Host "  ===============" -ForegroundColor DarkGray
        Write-Host "  Script Management Platform" -ForegroundColor Gray
        if ($script:DebugMode) {
            Write-Host "  DEBUG MODE AKTIV" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    # Sichere Eingabe-Funktion
    function Read-SecureInput {
        param(
            [string]$Prompt,
            [switch]$AsPlainText
        )
        
        if ($AsPlainText) {
            return Read-Host $Prompt
        }
        
        $secure = Read-Host $Prompt -AsSecureString
        
        # Cross-Platform sichere String-Konvertierung
        try {
            # Neue Methode für .NET Core
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
            # Fallback für ältere Versionen
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
            try {
                return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }
    }

    # API-Aufruf mit Fehlerbehandlung
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
                throw "Authentifizierung fehlgeschlagen. Bitte Zugangsdaten prüfen."
            }
            elseif ($statusCode -eq 429) {
                throw "Zu viele Anfragen. Bitte kurz warten."
            }
            elseif ($statusCode -eq 404) {
                throw "Endpunkt nicht gefunden: $Endpoint"
            }
            elseif ($statusCode -ge 500) {
                throw "Server-Fehler ($statusCode): $statusDescription"
            }
            else {
                throw "API-Fehler: $_"
            }
        }
    }

    # Authentifizierung
    Show-Banner
    
    try {
        if ($UsePassword) {
            Write-Host "  Passwort-Authentifizierung" -ForegroundColor Yellow
            $password = Read-SecureInput -Prompt "  Passwort"
            $script:Headers = @{ 'X-API-Key' = $password }
        }
        elseif ($ApiKey) {
            $script:Headers = @{ 'X-API-Key' = $ApiKey }
        }
        else {
            Write-Host "  API-Key erforderlich" -ForegroundColor Yellow
            $key = Read-SecureInput -Prompt "  API-Key"
            $script:Headers = @{ 'X-API-Key' = $key }
        }

        # Authentifizierung testen
        Write-Host ""
        Write-Host "  Verbinde..." -ForegroundColor Gray
        
        $auth = Invoke-ApiRequest -Endpoint 'auth' -Method 'POST'
        
        if ($auth.authenticated) {
            Write-Host "  ✓ Erfolgreich verbunden!" -ForegroundColor Green
            if ($auth.sessionToken) {
                $script:Headers['X-Session-Token'] = $auth.sessionToken
            }
            Start-Sleep -Milliseconds 500
        }
        else {
            throw "Authentifizierung fehlgeschlagen"
        }
    }
    catch {
        Write-Host "  ✗ Fehler: $_" -ForegroundColor Red
        return
    }

    # Hauptmenü
    MainMenu
}

function MainMenu {
    while ($true) {
        try {
            Show-Banner
            
            # Menü laden mit Fehlerbehandlung
            Write-Host "  Lade Repository..." -ForegroundColor Gray
            $menu = Invoke-ApiRequest -Endpoint 'menu'
            
            # Scripts sammeln mit verbesserter Performance
            $allScripts = [System.Collections.Generic.List[PSObject]]::new()
            CollectScripts -Node $menu -Scripts $allScripts
            
            if ($allScripts.Count -eq 0) {
                Write-Host "  ⚠ Keine Scripts im Repository gefunden." -ForegroundColor Yellow
                Write-Host ""
                Read-Host "  Enter zum Beenden"
                return
            }
            
            Write-Host "  Repository: $($allScripts.Count) Scripts" -ForegroundColor Yellow
            Write-Host ""
            
            # Nach Ordner gruppiert anzeigen mit Pagination
            Show-ScriptMenu -Scripts $allScripts
            
            Write-Host ""
            Write-Host "  [S] Suchen | [F] Filter | [H] Hilfe | [Q] Beenden" -ForegroundColor Cyan
            Write-Host ""
            
            $choice = Read-Host "  Auswahl"
            
            switch -Regex ($choice) {
                '^[Qq]$' { 
                    Write-Host "`n  Auf Wiedersehen!" -ForegroundColor Green
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
                        Write-Host "  ⚠ Ungültige Auswahl" -ForegroundColor Yellow
                        Start-Sleep -Seconds 1
                    }
                }
                default {
                    Write-Host "  ⚠ Ungültige Eingabe" -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
            }
        }
        catch {
            Write-Host "  Fehler: $_" -ForegroundColor Red
            Write-Host ""
            $retry = Read-Host "  Erneut versuchen? (J/N)"
            if ($retry -ne 'J' -and $retry -ne 'j') {
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
            Write-Host "  ... und $($Scripts.Count - $maxItemsPerScreen) weitere. Nutze [S]uche für mehr." -ForegroundColor Gray
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
    Write-Host "  Pfad: $($Script.FullPath)" -ForegroundColor Gray
    Write-Host "  Größe: $([math]::Round($Script.Size / 1KB, 1)) KB" -ForegroundColor Gray
    
    if ($Script.LastModified) {
        Write-Host "  Geändert: $($Script.LastModified)" -ForegroundColor Gray
    }
    
    if ($Script.Metadata -and $Script.Metadata.Count -gt 0) {
        Write-Host "  Metadaten:" -ForegroundColor Gray
        foreach ($key in $Script.Metadata.Keys) {
            Write-Host "    $key : $($Script.Metadata[$key])" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "  [1] Ausführen" -ForegroundColor Green
    Write-Host "  [2] Herunterladen" -ForegroundColor Yellow
    Write-Host "  [3] Inhalt anzeigen" -ForegroundColor Cyan
    Write-Host "  [4] In Zwischenablage kopieren" -ForegroundColor Magenta
    Write-Host "  [0] Zurück" -ForegroundColor Gray
    Write-Host ""
    
    $action = Read-Host "  Aktion"
    
    if ($action -in '1','2','3','4') {
        try {
            Write-Host ""
            Write-Host "  Lade Script..." -ForegroundColor Gray
            
            $response = Invoke-ApiRequest -Endpoint "script?path=$([Uri]::EscapeDataString($Script.Path))"
            
            if ($null -eq $response -or $null -eq $response.content) {
                throw "Leere Antwort vom Server"
            }
            
            switch ($action) {
                '1' { # Ausführen
                    Write-Host ""
                    Write-Host "  ⚠ WARNUNG: Sie sind dabei, ein Script auszuführen!" -ForegroundColor Yellow
                    Write-Host "  Nur fortfahren, wenn Sie dem Script vertrauen." -ForegroundColor Yellow
                    Write-Host ""
                    
                    if ($response.contentHash) {
                        Write-Host "  Script-Hash: $($response.contentHash)" -ForegroundColor Gray
                    }
                    
                    $confirm = Read-Host "  Script wirklich ausführen? (JA zum Bestätigen)"
                    if ($confirm -eq 'JA') {
                        Write-Host ""
                        Write-Host "  === Ausführung ===" -ForegroundColor Cyan
                        Write-Host ""
                        
                        try {
                            # Script in isoliertem Scope ausführen
                            $scriptBlock = [scriptblock]::Create($response.content)
                            & $scriptBlock
                        }
                        catch {
                            Write-Host "  Script-Fehler: $_" -ForegroundColor Red
                        }
                        
                        Write-Host ""
                        Write-Host "  === Ende ===" -ForegroundColor Cyan
                    }
                    else {
                        Write-Host "  Ausführung abgebrochen." -ForegroundColor Yellow
                    }
                }
                '2' { # Download
                    $fileName = Split-Path $Script.Path -Leaf
                    $defaultPath = Join-Path ([Environment]::GetFolderPath('Desktop')) $fileName
                    
                    Write-Host "  Standard-Speicherort: $defaultPath" -ForegroundColor Gray
                    $savePath = Read-Host "  Speichern als (Enter für Standard)"
                    
                    if ([string]::IsNullOrWhiteSpace($savePath)) { 
                        $savePath = $defaultPath 
                    }
                    
                    try {
                        $response.content | Out-File -FilePath $savePath -Encoding UTF8 -Force
                        Write-Host "  ✓ Gespeichert: $savePath" -ForegroundColor Green
                        
                        # Öffnen-Option anbieten
                        $open = Read-Host "  Datei öffnen? (J/N)"
                        if ($open -eq 'J' -or $open -eq 'j') {
                            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                                Start-Process notepad.exe -ArgumentList $savePath
                            }
                            elseif ($IsMacOS) {
                                Start-Process open -ArgumentList $savePath
                            }
                            else {
                                Write-Host "  Bitte öffnen Sie die Datei manuell." -ForegroundColor Yellow
                            }
                        }
                    }
                    catch {
                        Write-Host "  Fehler beim Speichern: $_" -ForegroundColor Red
                    }
                }
                '3' { # Anzeigen
                    Write-Host ""
                    Write-Host "  === Inhalt von $($Script.Name) ===" -ForegroundColor Cyan
                    Write-Host ""
                    
                    # Syntax-Highlighting für bessere Lesbarkeit
                    $lines = $response.content -split "`n"
                    $lineNumber = 1
                    
                    foreach ($line in $lines) {
                        # Einfaches Syntax-Highlighting
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
                        
                        # Pagination für lange Scripts
                        if ($lineNumber % 30 -eq 0) {
                            $cont = Read-Host "  --- Mehr anzeigen? (Enter/Q) ---"
                            if ($cont -eq 'Q' -or $cont -eq 'q') { break }
                        }
                    }
                    
                    Write-Host ""
                    Write-Host "  === Ende (${lineNumber} Zeilen) ===" -ForegroundColor Cyan
                }
                '4' { # In Zwischenablage
                    try {
                        if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                            $response.content | Set-Clipboard
                            Write-Host "  ✓ In Zwischenablage kopiert!" -ForegroundColor Green
                        }
                        else {
                            Write-Host "  ⚠ Zwischenablage nicht verfügbar auf diesem System." -ForegroundColor Yellow
                            Write-Host "  Nutzen Sie Option [2] zum Speichern." -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-Host "  Fehler beim Kopieren: $_" -ForegroundColor Red
                    }
                }
            }
        }
        catch {
            Write-Host "  Fehler: $_" -ForegroundColor Red
        }
        
        Write-Host ""
        Read-Host "  Enter zum Fortfahren"
    }
}

function SearchScripts {
    param($Scripts)
    
    Clear-Host
    Write-Host ""
    Write-Host "  Suche" -ForegroundColor Cyan
    Write-Host "  =====" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Tipp: Verwende * als Wildcard (z.B. *test*)" -ForegroundColor Gray
    Write-Host ""
    
    $search = Read-Host "  Suchbegriff"
    if ([string]::IsNullOrWhiteSpace($search)) { return }
    
    # Erweiterte Suche
    $found = $Scripts | Where-Object { 
        $_.Name -like "*$search*" -or 
        $_.FullPath -like "*$search*" -or
        ($_.Metadata.description -and $_.Metadata.description -like "*$search*") -or
        ($_.Metadata.author -and $_.Metadata.author -like "*$search*")
    }
    
    if ($found) {
        Write-Host ""
        Write-Host "  Gefunden: $($found.Count) Ergebnis(se)" -ForegroundColor Green
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
        $selection = Read-Host "  Auswahl (Nummer oder Enter)"
        
        if ($selection -match '^\d+$') {
            $selectedIndex = [int]$selection - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $found.Count) {
                ShowScriptActions -Script $found[$selectedIndex]
            }
        }
    }
    else {
        Write-Host "  Keine Ergebnisse für '$search' gefunden." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "  Enter zum Fortfahren"
    }
}

function FilterScripts {
    param($Scripts)
    
    Clear-Host
    Write-Host ""
    Write-Host "  Filter" -ForegroundColor Cyan
    Write-Host "  =======" -ForegroundColor DarkGray
    Write-Host ""
    
    # Verfügbare Ordner anzeigen
    $folders = $Scripts | ForEach-Object { Split-Path $_.FullPath -Parent } | 
               Where-Object { $_ } | Select-Object -Unique | Sort-Object
    
    if ($folders) {
        Write-Host "  Verfügbare Ordner:" -ForegroundColor Yellow
        $index = 1
        foreach ($folder in $folders) {
            Write-Host "  [$index] $folder" -ForegroundColor Green
            $index++
        }
        
        Write-Host ""
        $selection = Read-Host "  Ordner wählen (Nummer)"
        
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
                $scriptSelection = Read-Host "  Script wählen (Nummer)"
                
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
        Write-Host "  Keine Ordner gefunden." -ForegroundColor Yellow
        Read-Host "  Enter zum Fortfahren"
    }
}

function ShowHelp {
    Clear-Host
    Write-Host ""
    Write-Host "  InvokeHub Hilfe" -ForegroundColor Cyan
    Write-Host "  ===============" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Navigation:" -ForegroundColor Yellow
    Write-Host "    - Nummer eingeben: Script direkt auswählen"
    Write-Host "    - [S]: Nach Scripts suchen (Name, Pfad, Metadaten)"
    Write-Host "    - [F]: Nach Ordner filtern"
    Write-Host "    - [H]: Diese Hilfe anzeigen"
    Write-Host "    - [Q]: Programm beenden"
    Write-Host ""
    Write-Host "  Script-Aktionen:" -ForegroundColor Yellow
    Write-Host "    - [1]: Script ausführen (mit Sicherheitswarnung)"
    Write-Host "    - [2]: Script herunterladen"
    Write-Host "    - [3]: Script-Inhalt anzeigen"
    Write-Host "    - [4]: In Zwischenablage kopieren"
    Write-Host "    - [0]: Zurück zum Hauptmenü"
    Write-Host ""
    Write-Host "  Sicherheit:" -ForegroundColor Red
    Write-Host "    - Führe nur Scripts aus vertrauenswürdigen Quellen aus"
    Write-Host "    - Prüfe den Inhalt vor der Ausführung (Option 3)"
    Write-Host "    - Scripts werden in isoliertem Scope ausgeführt"
    Write-Host ""
    Write-Host "  Tipps:" -ForegroundColor Green
    Write-Host "    - Verwende Wildcards (*) bei der Suche"
    Write-Host "    - Scripts können Metadaten enthalten (Autor, Beschreibung)"
    Write-Host "    - Die API unterstützt Passwort- oder API-Key-Authentifizierung"
    Write-Host ""
    Write-Host "  Über InvokeHub:" -ForegroundColor Cyan
    Write-Host "    InvokeHub ist eine sichere Platform zur Verwaltung"
    Write-Host "    und Ausführung von PowerShell Scripts."
    Write-Host "    Version: 1.0.0"
    Write-Host ""
    Read-Host "  Enter zum Fortfahren"
}