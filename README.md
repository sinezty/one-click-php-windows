# One-Click PHP Setup (Windows)

This project provides scripts to prepare a PHP development environment on Windows with a single command. It handles PHP version detection and upgrade, placing PHP at a standard path (`C:\php`), enabling key php.ini extensions, and adding a right-click menu entry to quickly start PHP’s built-in web server.

## Features
- Downloads official PHP binaries directly (Portable, no Admin install required for PHP itself)
- Detects existing PHP versions (PATH or `C:\php`)
- Supports installing multiple PHP versions side-by-side (8.4, 8.3, 8.2)
- Places portable PHP versions under `C:\php`
- Enables common php.ini extensions (sqlite, curl, zip, etc.)
- Adds a context menu entry to open the selected folder with a specific PHP version
- Context-driven version selection from the right-click menu
- Installer focuses on install/repair; skips re-download for installed versions unless requested

![Features](docs/install.png)

## Requirements
- Windows 10/11 (run with Administrator privileges)
- Internet access (for downloading PHP binaries)
- PowerShell execution permission (script temporarily bypasses ExecutionPolicy)

## Installation
1. Run installation.bat with “Run as administrator”.
2. If PHP exists on PATH, it’s used directly. Otherwise, the installer downloads an official PHP zip (you select the version) and extracts it to `C:\php`.
3. Adds a context menu entry: “Open in Browser (PHP)”.

### Run from GitHub (Administrator PowerShell, current session)
Run these three lines (no backticks in URL):
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/sinezty/one-click-php-windows/main/installation.ps1'))
```

Alternative using Invoke-WebRequest:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$u = 'https://raw.githubusercontent.com/sinezty/one-click-php-windows/main/installation.ps1'
$s = (Invoke-WebRequest -UseBasicParsing $u).Content
iex $s
```

CMD one-liner (Admin):
```cmd
cmd /c powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/sinezty/one-click-php-windows/main/installation.ps1'))"
```

Download to file and run (when policies are strict):
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dest = "$env:TEMP\installation.ps1"
Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/sinezty/one-click-php-windows/main/installation.ps1' -OutFile $dest
powershell -NoProfile -ExecutionPolicy Bypass -File $dest
```

### Repository
- GitHub: https://github.com/sinezty/one-click-php-windows/tree/main

## Uninstall
- Removes `C:\php`, the context menu entry, and temp files.
- Administrator PowerShell:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$u = 'https://raw.githubusercontent.com/sinezty/one-click-php-windows/main/installation.ps1'
$dest = "$env:TEMP\installation.ps1"
Invoke-WebRequest -UseBasicParsing $u -OutFile $dest
powershell -NoProfile -ExecutionPolicy Bypass -File $dest -Uninstall
```
- CMD (Admin):
```cmd
cmd /c powershell -NoProfile -ExecutionPolicy Bypass -Command "$u='https://raw.githubusercontent.com/sinezty/one-click-php-windows/main/installation.ps1'; $d=\"$env:TEMP\\installation.ps1\"; (Invoke-WebRequest -UseBasicParsing $u -OutFile $d); powershell -NoProfile -ExecutionPolicy Bypass -File $d -Uninstall"
```

## Usage
- Quick server: right-click a folder -> "Open in Browser (PHP)" -> Select PHP Version.
- The server starts on an available port (8000+) and opens your default browser.
- Manual start: in your project directory run `php -S localhost:8000`.

## Port Management
- Maintains a JSON mapping of folders to ports at `%TEMP%\php-server-ports.json`.
- Reuses the assigned port for a folder if the port is still available; otherwise, selects a new one.
- Checks port availability using system TCP connections, netstat, and a short TcpListener probe.
- Derives a deterministic base port from the folder path (8000–8999) and iterates to find a free port; falls back to random selection if needed.
- Updates the JSON file on every launch so multiple folders can run concurrently on different ports.
- Uninstall removes the JSON file along with the context menu and launcher.

## Configuration
- Supports PHP 8.2+

## Files
- `installation.ps1`: main PowerShell installation script
- `installation.bat`: helper to launch the PowerShell script
- `php-server-launcher.ps1`: script started from the context menu to launch the PHP server

## Notes
- The installer uses official Windows PHP zips. You can select the PHP version (8.4/8.3/8.2, NTS/TS, x64).

## Troubleshooting
- Access is denied: run PowerShell/CMD as Administrator. Some environments enforce policies (WDAC/AppLocker) that block starting new powershell.exe; prefer running inside the current PowerShell session (see “Run from GitHub” above).
- URL parsing issues: do not wrap URLs with backticks or add extra spaces. Use a plain single-quoted URL as shown.
- ExecutionPolicy blocked: open PowerShell as Administrator and use `-ExecutionPolicy Bypass`. The script attempts a temporary bypass and shows a warning if restricted.
- TLS/download issues: ensure TLS 1.2 is enabled as shown above. If downloads fail, use the Invoke-WebRequest variant or the download-to-file method.

2026 BarışY
