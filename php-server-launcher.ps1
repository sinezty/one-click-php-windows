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

try {
    Start-Process $url
} catch {
    Write-Host "Warning: Could not open browser automatically. Please open $url manually." -ForegroundColor Yellow
}

Push-Location $FolderPath
& $phpCmd -S localhost:$port
Pop-Location
