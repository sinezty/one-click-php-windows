param([switch]$Uninstall)
try { Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop } catch { Write-Host "WARNING: ExecutionPolicy is restricted. Run PowerShell with -ExecutionPolicy Bypass." -ForegroundColor Yellow }
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (!$isAdmin) {
    Write-Host "`nERROR: This script requires administrator privileges!" -ForegroundColor Red
    Write-Host "Open PowerShell with 'Run as administrator'.`n" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   PHP FULL SETUP (SQLite)              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$portableRoot = "C:\php"


if ($Uninstall) {
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   UNINSTALL                            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    $regPath = "HKCU:\Software\Classes\Directory\shell\PHPServer"
    try {
        if (Test-Path $regPath) {
            Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "OK Context menu removed" -ForegroundColor Green
        } else {
            Write-Host "OK Context menu not found" -ForegroundColor Green
        }
    } catch {
        Write-Host "WARNING: Context menu could not be removed: $_" -ForegroundColor Yellow
    }
    $launcherPaths = @()
    $portFile = "$env:TEMP\php-server-ports.json"
    try { if (Test-Path $portFile) { Remove-Item $portFile -Force -ErrorAction SilentlyContinue } } catch {}
    $portableRoot = "C:\php"
    try { if (Test-Path $portableRoot) { Remove-Item $portableRoot -Recurse -Force -ErrorAction SilentlyContinue } } catch {}
    $portFile = "$env:TEMP\php-server-ports.json"
    try { if (Test-Path $portFile) { Remove-Item $portFile -Force -ErrorAction SilentlyContinue } } catch {}
    Write-Host "`nUNINSTALL COMPLETE" -ForegroundColor Green
    exit 0
}


Write-Host "`n[1/3] Select and install PHP (Official Zip)..." -ForegroundColor Yellow

function Get-PhpDownloadOptions {
    $urls = @(
        "https://windows.php.net/downloads/releases/",
        "https://windows.php.net/download/"
    )
    $items = @()
    
    # Enable TLS 1.2+
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    foreach ($u in $urls) {
        try {
            # Use Invoke-WebRequest with UserAgent
            $html = Invoke-WebRequest -Uri $u -UseBasicParsing -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -ErrorAction Stop
            $text = $html.Content
            
            # Match filenames (relative or absolute)
            $matches = ([regex]::Matches($text, "(?<file>php-(?<ver>8\.\d+(?:\.\d+)*)-(?<nts>nts-)?Win32-(?<vs>vs\d+)-x64\.zip)"))
            
            foreach ($m in $matches) {
                $file = $m.Groups["file"].Value
                $ver = $m.Groups["ver"].Value
                $nts = $m.Groups["nts"].Value
                $vs = $m.Groups["vs"].Value
                
                # Construct clean absolute URL
                $url = "https://windows.php.net/downloads/releases/$file"
                $name = "PHP $ver " + ($(if ($nts) {"NTS"} else {"TS"})) + " x64 ($vs)"
                $tag = "php-$ver-" + ($(if ($nts) {"nts"} else {"ts"}) + "-$vs-x64")
                
                if ($items.Name -notcontains $name) {
                    $items += @{ Name = $name; Url = $url; Tag = $tag; Version = [version]$ver }
                }
            }
        } catch {
            # Ignore errors and try next URL
        }
        if ($items.Count -gt 0) { break }
    }
    
    # Fallback if scraping fails
    if ($items.Count -eq 0) {
        $items = @(
            @{ Name = "PHP 8.4.16 NTS x64 (VS17)"; Url = "https://windows.php.net/downloads/releases/php-8.4.16-nts-Win32-vs17-x64.zip"; Tag = "php-8.4.16-nts-vs17-x64"; Version = [version]"8.4.16" },
            @{ Name = "PHP 8.4.16 TS x64 (VS17)";  Url = "https://windows.php.net/downloads/releases/php-8.4.16-Win32-vs17-x64.zip";       Tag = "php-8.4.16-ts-vs17-x64";  Version = [version]"8.4.16" },
            @{ Name = "PHP 8.3.29 NTS x64 (VS16)"; Url = "https://windows.php.net/downloads/releases/php-8.3.29-nts-Win32-vs16-x64.zip"; Tag = "php-8.3.29-nts-vs16-x64"; Version = [version]"8.3.29" },
            @{ Name = "PHP 8.3.29 TS x64 (VS16)";  Url = "https://windows.php.net/downloads/releases/php-8.3.29-Win32-vs16-x64.zip";       Tag = "php-8.3.29-ts-vs16-x64";  Version = [version]"8.3.29" },
            @{ Name = "PHP 8.2.30 NTS x64 (VS16)"; Url = "https://windows.php.net/downloads/releases/php-8.2.30-nts-Win32-vs16-x64.zip"; Tag = "php-8.2.30-nts-vs16-x64"; Version = [version]"8.2.30" },
            @{ Name = "PHP 8.2.30 TS x64 (VS16)";  Url = "https://windows.php.net/downloads/releases/php-8.2.30-Win32-vs16-x64.zip";       Tag = "php-8.2.30-ts-vs16-x64";  Version = [version]"8.2.30" }
        )
    }
    $items | Sort-Object Version -Descending
}

function Get-PhpCandidates {
    param (
        [string]$ExtraPath = $null
    )
    $cands = @()
    
    # 1. Check the newly installed/verified path
    if ($ExtraPath -and (Test-Path (Join-Path $ExtraPath "php.exe"))) {
        $ver = & (Join-Path $ExtraPath "php.exe") -r "echo PHP_VERSION;" 2>$null
        $cands += @{ Label = "PHP $ver"; PhpExe = (Join-Path $ExtraPath "php.exe") }
    }
    
    # 2. Check PATH
    if (Get-Command php -ErrorAction SilentlyContinue) {
        $pathPhp = (Get-Command php).Source
        $ver2 = & $pathPhp -r "echo PHP_VERSION;" 2>$null
        
        # Avoid duplicates
        if ($cands.PhpExe -notcontains $pathPhp) {
            $cands += @{ Label = "PHP $ver2 (System)"; PhpExe = $pathPhp }
        }
    }
    
    # 3. Check all portable directories
    $pRoot = "C:\php"
    $portableDirs = @()
    if (Test-Path $pRoot) {
        $portableDirs = Get-ChildItem -Path $pRoot -Directory -ErrorAction SilentlyContinue
    }
    
    foreach ($dir in $portableDirs) {
        $exe = Join-Path $dir.FullName "php.exe"
        if (Test-Path $exe) {
            $ver3 = & $exe -r "echo PHP_VERSION;" 2>$null
            if ($cands.PhpExe -notcontains $exe) {
                $cands += @{ Label = "PHP $ver3"; PhpExe = $exe }
            }
        }
    }
    $cands
}

$phpFound = $false
$sourceDir = $null
$candidates = Get-PhpCandidates
 
Write-Host "`n[1/3] Install or repair PHP..." -ForegroundColor Yellow
 
$installedTags = @()
if (Test-Path $portableRoot) {
    $installedTags = Get-ChildItem -Path $portableRoot -Directory | Select-Object -ExpandProperty Name
}
 
$doInstallNew = $false
if (($installedTags.Count -gt 0) -or ($candidates.Count -gt 0)) {
    Write-Host "Detected installed PHP versions:" -ForegroundColor Gray
    foreach ($cand in $candidates) {
        Write-Host (" - {0}" -f $cand.Label) -ForegroundColor Gray
    }
    $ans = Read-Host "Install a new PHP version? (y/n) [n]"
    if ($ans -eq "y") { $doInstallNew = $true }
} else {
    $doInstallNew = $true
}
 
if ($doInstallNew) {
    $options = Get-PhpDownloadOptions
    for ($i=0; $i -lt $options.Count; $i++) {
        $opt = $options[$i]
        $status = ""
        if ($installedTags -contains $opt.Tag) { $status = " (Installed)" }
        Write-Host ("[{0}] {1}{2}" -f ($i+1), $opt.Name, $status)
    }
    $choice = Read-Host ("Select option [1-{0}] (default 1)" -f $options.Count)
    if (-not $choice -or -not ($choice -as [int]) -or ([int]$choice -lt 1) -or ([int]$choice -gt $options.Count)) { $choice = 1 } else { $choice = [int]$choice }
    $sel = $options[$choice-1]
    $zipUrl = $sel.Url
    $destDir = Join-Path $portableRoot $sel.Tag
    $zipFile = Join-Path $env:TEMP "php-selected.zip"
    Write-Host ("Selected: {0}" -f $sel.Name) -ForegroundColor Cyan
    $doDownload = $true
    if (Test-Path $destDir) {
        Write-Host "This version is already installed." -ForegroundColor Yellow
        $reinstall = Read-Host "Redownload and reinstall? (y/n) [n]"
        if ($reinstall -ne "y") {
            $doDownload = $false
            $sourceDir = $destDir
            $phpFound = $true
            Write-Host "Skipping download. Using existing installation." -ForegroundColor Green
        } else {
            Write-Host "Re-installing..." -ForegroundColor Gray
        }
    } else {
        Write-Host "Installing..." -ForegroundColor Gray
    }
    if ($doDownload) {
        try {
            Write-Host "Downloading..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -ErrorAction Stop
            if (Test-Path $destDir) { Remove-Item $destDir -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $destDir)
            Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
            if (Test-Path (Join-Path $destDir "php.exe")) {
                $sourceDir = $destDir
                $phpFound = $true
                Write-Host ("OK Installed/Updated: {0}" -f $sel.Name) -ForegroundColor Green
            } else {
                Write-Host "ERROR: php.exe not found after extraction." -ForegroundColor Red
            }
        } catch {
            Write-Host "ERROR: PHP download/extract failed: $_" -ForegroundColor Red
        }
    }
} else {
    $phpFound = $true
}

    Start-Sleep -Seconds 2

if (!(Get-Command php -ErrorAction SilentlyContinue)) {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    $userPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
    $env:Path = "$machinePath;$userPath"
}
 
if (-not $sourceDir) {
    try {
        $bestCand = $null
        $bestVer = [version]"0.0.0"
        foreach ($cand in $candidates) {
            $vstr = & $cand.PhpExe -r "echo PHP_VERSION;" 2>$null
            $vobj = $null
            try { $vobj = [version]$vstr } catch { $vobj = [version]"0.0.0" }
            if ($vobj -gt $bestVer) { $bestVer = $vobj; $bestCand = $cand }
        }
        if ($bestCand) {
            $sourceDir = Split-Path -Parent $bestCand.PhpExe
        }
    } catch {}
}
 
try {
    $finalSource = $null
    if ($sourceDir -and (Test-Path (Join-Path $sourceDir "php.exe"))) { $finalSource = $sourceDir }
    if (-not $finalSource -and (Get-Command php -ErrorAction SilentlyContinue)) {
        $phpExePathFinal = (Get-Command php).Source
        $phpDirFinal = Split-Path -Parent $phpExePathFinal
        if ($phpDirFinal -and (Test-Path (Join-Path $phpDirFinal "php.exe"))) { $finalSource = $phpDirFinal }
    }
 
    if ($finalSource) {
        $phpVersionStd = & (Join-Path $finalSource "php.exe") -r "echo PHP_VERSION;" 2>$null
    if ($phpVersionStd) {
        Write-Host "OK PHP ready: $phpVersionStd" -ForegroundColor Green
    } else {
        Write-Host "WARNING: PHP version check failed." -ForegroundColor Yellow
    }
} else {
    Write-Host "ERROR: PHP binaries not found." -ForegroundColor Red
}
} catch {
    Write-Host "ERROR: Standardization failed: $_" -ForegroundColor Red
}

Write-Host "`n[2/3] Enabling PHP extensions..." -ForegroundColor Yellow
Write-Host "      (including SQLite, curl, zip, etc.)" -ForegroundColor Gray

$installedPhpExe = $null
if ($finalSource -and (Test-Path (Join-Path $finalSource "php.exe"))) { $installedPhpExe = Join-Path $finalSource "php.exe" }
elseif (Get-Command php -ErrorAction SilentlyContinue) { $installedPhpExe = (Get-Command php).Source }

if ($installedPhpExe) {
    $iniPath = $null
    try {
        $phpExePath = $installedPhpExe
        $phpDir = Split-Path -Parent $phpExePath
        
        $iniOutput = & $phpExePath --ini 2>$null
        if ($iniOutput) {
            $iniLine = $iniOutput | Select-String "Loaded Configuration File" | Select-Object -First 1
            if ($iniLine) {
                $iniLineText = $iniLine.ToString()
                if ($iniLineText -match ":\s*(.+)") {
                    $iniPath = $matches[1].Trim()
                    $iniPath = $iniPath -replace '"', ''
                    $iniPath = $iniPath -replace "'", ''
                    $iniPath = $iniPath.TrimStart().TrimEnd()
                    $iniPath = $iniPath.Trim()
                }
            }
        }
    } catch {
        Write-Host "php --ini failed, trying alternatives..." -ForegroundColor Gray
    }
    
    $phpDir = $null
    try {
        $phpExePath = $installedPhpExe
        $phpDir = Split-Path -Parent $phpExePath
    } catch {}
    
    if (!$iniPath -or !(Test-Path $iniPath)) {
        $possibleIniPaths = @()
        
        if ($finalSource) {
            $possibleIniPaths += @(Join-Path $finalSource "php.ini")
            $possibleIniPaths += @(Join-Path $finalSource "php.ini-production")
            $possibleIniPaths += @(Join-Path $finalSource "php.ini-development")
        }
        
        foreach ($path in $possibleIniPaths) {
            if ($path -and (Test-Path $path)) {
                $iniPath = $path
                break
            }
        }
    }
    
    if ($iniPath) {
        $iniPath = $iniPath.Trim()
        $iniPath = $iniPath -replace '"', ''
        $iniPath = $iniPath -replace "'", ''
        $iniPath = $iniPath.Trim()
    }
    
    if ($iniPath -and (Test-Path $iniPath)) {
        try {
            $iniContent = Get-Content $iniPath
            $newContent = @()
            $enabledCount = 0
            $modified = $false
            
            foreach ($line in $iniContent) {
                if ($line -match "^;\s*extension\s*=") {
                    $newLine = $line -replace "^;\s*", ""
                    $newContent += $newLine
                    $enabledCount++
                    $modified = $true
                } else {
                    $newContent += $line
                }
            }
            
            if ($modified) {
                $backupPath = "$iniPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item $iniPath $backupPath -ErrorAction SilentlyContinue
                
                $newContent | Set-Content $iniPath -Encoding UTF8 -ErrorAction SilentlyContinue
                Write-Host "OK $enabledCount extensions enabled!" -ForegroundColor Green
            } else {
                Write-Host "OK All extensions already enabled." -ForegroundColor Green
            }
        } catch {
            Write-Host "WARNING: php.ini could not be modified: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "WARNING: php.ini file not found." -ForegroundColor Yellow
    }
} else {
    if ($finalSource) {
        $iniPath = $null
        $iniCandidates = @(
            (Join-Path $finalSource "php.ini"),
            (Join-Path $finalSource "php.ini-production"),
            (Join-Path $finalSource "php.ini-development")
        )
        foreach ($p in $iniCandidates) {
            if (Test-Path $p) { $iniPath = $p; break }
        }
        if (-not $iniPath) {
            try {
                $iniPath = (Join-Path $finalSource "php.ini")
                Set-Content $iniPath @(
                    "[PHP]",
                    "extension_dir = ""ext"""
                ) -Encoding UTF8
            } catch {}
        }
        if ($iniPath -and (Test-Path $iniPath)) {
            try {
                $iniContent = Get-Content $iniPath
                $newContent = @()
                $enabledCount = 0
                $modified = $false
                $hasExtDir = $false
                foreach ($line in $iniContent) {
                    $l = $line
                    if ($l -match "^\s*;\s*extension\s*=") {
                        $l = $l -replace "^;\s*", ""
                        $enabledCount++
                        $modified = $true
                    }
                    if ($l -match "^\s*extension_dir\s*=") { $hasExtDir = $true }
                    $newContent += $l
                }
                if (-not $hasExtDir) {
                    $newContent = @("extension_dir = ""ext""") + $newContent
                    $modified = $true
                }
                if ($modified) {
                    $backupPath = "$iniPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                    Copy-Item $iniPath $backupPath -ErrorAction SilentlyContinue
                    $newContent | Set-Content $iniPath -Encoding UTF8 -ErrorAction SilentlyContinue
                    Write-Host "OK $enabledCount extensions enabled!" -ForegroundColor Green
                } else {
                    Write-Host "OK Extensions already configured." -ForegroundColor Green
                }
            } catch {
                Write-Host "WARNING: php.ini could not be modified: $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host "WARNING: php.ini file not found." -ForegroundColor Yellow
        }
    } else {
        Write-Host "WARNING: PHP not found, extensions could not be enabled." -ForegroundColor Yellow
    }
}

Write-Host "`n[3/3] Installing context menu..." -ForegroundColor Yellow

$menuName = "Open in Browser (PHP)"
$contextMenuReady = $false

$candidates = Get-PhpCandidates -ExtraPath $finalSource
if ($candidates.Count -eq 0) {
    Write-Host "WARNING: PHP not found, launcher script could not be created!" -ForegroundColor Yellow
    Write-Host "Skipping context menu installation." -ForegroundColor Yellow
} else {
    $launcherPath = Join-Path $portableRoot "php-server-launcher.ps1"
    Write-Host "Saving launcher script: $launcherPath" -ForegroundColor Gray

$launcherContent = @'
param([string]$FolderPath, [string]$PhpExePath)

Add-Type -AssemblyName System.Windows.Forms

if ([string]::IsNullOrWhiteSpace($FolderPath)) {
    $FolderPath = Get-Location
}

if (!(Test-Path $FolderPath)) {
    [System.Windows.Forms.MessageBox]::Show("Folder not found: $FolderPath", "Error", "OK", "Error")
    exit 1
}

$phpCmd = $null
if ($PhpExePath -and (Test-Path $PhpExePath)) { $phpCmd = $PhpExePath }
elseif (Get-Command php -ErrorAction SilentlyContinue) { $phpCmd = (Get-Command php).Source }
if (-not $phpCmd) { [System.Windows.Forms.MessageBox]::Show("PHP not found! Please install first.", "Error", "OK", "Error"); exit 1 }

$portFile = "$env:TEMP\php-server-ports.json"

$activePorts = @{}
if (Test-Path $portFile) {
    try {
        $savedData = Get-Content $portFile -Raw | ConvertFrom-Json
        if ($savedData) {
            $savedData.PSObject.Properties | ForEach-Object {
                $activePorts[$_.Name] = $_.Value
            }
        }
    } catch {}
}

function Test-PortAvailable {
    param([int]$Port)
    
    try {
        $connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        if ($connections) {
            return $false
        }
        
        $netstat = netstat -an | Select-String ":$Port\s"
        if ($netstat) {
            return $false
        }
        
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        $listener.Stop()
        return $true
    } catch {
        return $false
    }
}

function Get-PortForFolder {
    param([string]$FolderPath)
    
    $folderKey = $FolderPath
    
    if ($activePorts.ContainsKey($folderKey)) {
        $assignedPort = $activePorts[$folderKey]
        if (Test-PortAvailable -Port $assignedPort) {
            if ($activePorts.Values -notcontains $assignedPort -or $activePorts[$folderKey] -eq $assignedPort) {
                return $assignedPort
            }
        }
        $activePorts.Remove($folderKey)
    }
    
    if ($activePorts.Values -notcontains 80) {
        if (Test-PortAvailable -Port 80) {
            $activePorts[$folderKey] = 80
            return 80
        }
    }
    
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($FolderPath))
    $folderHash = [BitConverter]::ToString($hashBytes).Replace("-", "").Substring(0, 8)
    
    $hashInt = [Convert]::ToInt32($folderHash, 16)
    $basePort = 8000 + ($hashInt % 1000)
    
    $port = $basePort
    $maxAttempts = 100
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        if ($activePorts.Values -contains $port) {
            $port = 8000 + (($basePort + $attempt) % 1000)
            $attempt++
            continue
        }
        
        if (Test-PortAvailable -Port $port) {
            $activePorts[$folderKey] = $port
            return $port
        }
        
        $port = 8000 + (($basePort + $attempt) % 1000)
        $attempt++
    }
    
    $random = Get-Random -Minimum 8000 -Maximum 9000
    for ($i = 0; $i -lt 100; $i++) {
        $testPort = $random + $i
        if ($testPort -gt 8999) { $testPort = 8000 + ($testPort - 9000) }
        
        if ($activePorts.Values -notcontains $testPort) {
            if (Test-PortAvailable -Port $testPort) {
                $activePorts[$folderKey] = $testPort
                return $testPort
            }
        }
    }
    
    if (Test-PortAvailable -Port 8000) {
        $activePorts[$folderKey] = 8000
        return 8000
    }
    
    for ($p = 8001; $p -lt 9000; $p++) {
        if ($activePorts.Values -notcontains $p) {
            if (Test-PortAvailable -Port $p) {
                $activePorts[$folderKey] = $p
                return $p
            }
        }
    }
    
    return 8000
}

$port = Get-PortForFolder -FolderPath $FolderPath

try {
    $activePorts | ConvertTo-Json -Depth 10 | Set-Content $portFile -ErrorAction SilentlyContinue
} catch {}

$url = "http://localhost:$port"

$folderName = Split-Path -Leaf $FolderPath
try {
    $Host.UI.RawUI.WindowTitle = "PHP - $folderName : Port $port"
} catch {}

Write-Host "Starting PHP server..." -ForegroundColor Green
Write-Host "Folder: $FolderPath" -ForegroundColor Cyan
Write-Host "Port: $port" -ForegroundColor Cyan
Write-Host "URL: $url" -ForegroundColor Cyan
Write-Host ""

Start-Process $url

Push-Location $FolderPath
& $phpCmd -S localhost:$port
Pop-Location
'@

    try {
        $launcherContent | Set-Content $launcherPath -Encoding UTF8
        Write-Host "Launcher script created: $launcherPath" -ForegroundColor Green
        
        $parentKey = "HKCU:\Software\Classes\Directory\shell\PHPServer"
        $submenuKey = "HKCU:\Software\Classes\Directory\shell\PHPServer\shell"
        if (Test-Path $parentKey) { Remove-Item $parentKey -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -Path $parentKey -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $parentKey -Name "MUIVerb" -Value $menuName -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $parentKey -Name "SubCommands" -Value "" -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $parentKey -Name "Icon" -Value "powershell.exe" -ErrorAction SilentlyContinue
        New-Item -Path $submenuKey -Force -ErrorAction SilentlyContinue | Out-Null
        $index = 1
        foreach ($cand in $candidates) {
            $subKey = Join-Path $submenuKey ("v{0}" -f $index)
            $cmdKey = Join-Path $subKey "command"
            New-Item -Path $subKey -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path $subKey -Name "MUIVerb" -Value $cand.Label -ErrorAction SilentlyContinue
            New-Item -Path $cmdKey -Force -ErrorAction SilentlyContinue | Out-Null
            $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`" `"%1`" -PhpExePath `"$($cand.PhpExe)`""
            Set-ItemProperty -Path $cmdKey -Name "(default)" -Value $cmd -ErrorAction SilentlyContinue
            $index++
        }
        
        Write-Host "OK Context menu added!" -ForegroundColor Green
        Write-Host "Launcher script location: $launcherPath" -ForegroundColor Gray
        $contextMenuReady = $true
    } catch {
        Write-Host "WARNING: Context menu could not be added: $_" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  INSTALLATION COMPLETE!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

$phpCheck = $null
if ($installedPhpExe -and (Test-Path $installedPhpExe)) { $phpCheck = $installedPhpExe }
elseif ($finalSource -and (Test-Path (Join-Path $finalSource "php.exe"))) { $phpCheck = Join-Path $finalSource "php.exe" }
elseif (Get-Command php -ErrorAction SilentlyContinue) { $phpCheck = (Get-Command php).Source }

if ($phpCheck) {
    $phpVersion = & $phpCheck -r "echo PHP_VERSION;" 2>$null
    Write-Host "OK PHP version: $phpVersion" -ForegroundColor Green
    
    $sqlite3 = & $phpCheck -m 2>$null | Select-String "sqlite3"
    $pdo_sqlite = & $phpCheck -m 2>$null | Select-String "pdo_sqlite"
    if ($sqlite3 -or $pdo_sqlite) {
        Write-Host "OK SQLite: Active" -ForegroundColor Green
    }
} else {
    Write-Host "ERROR: PHP: Not installed" -ForegroundColor Red
}

if ($contextMenuReady) { Write-Host "OK Context menu: Ready" -ForegroundColor Green } else { Write-Host "WARNING: Context menu: Not ready" -ForegroundColor Yellow }

Write-Host "`nDONE! You can now right-click folders and use '$menuName'.`n" -ForegroundColor Cyan

Read-Host "Press Enter to exit"

