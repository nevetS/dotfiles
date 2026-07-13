#Requires -Version 5.1
# bin/install-deps.ps1 — install dotfiles dependencies on Windows
# Requires winget (ships with Windows 11 / Windows 10 1709+)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log-Ok   { param($msg) Write-Host "[✓] $msg" -ForegroundColor Green  }
function Log-Warn { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Log-Err  { param($msg) Write-Host "[✗] $msg" -ForegroundColor Red; exit 1 }

# ── winget check ──────────────────────────────────────────────────────────────
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Log-Err "winget not found. Install App Installer from the Microsoft Store."
}

# ── python3 ───────────────────────────────────────────────────────────────────
if (Get-Command python3 -ErrorAction SilentlyContinue) {
    $v = python3 --version 2>&1
    Log-Ok "python3 $v"
} else {
    Log-Warn "python3 not found — installing via winget"
    winget install -e --id Python.Python.3 --accept-source-agreements --accept-package-agreements
    Log-Ok "python3 installed"
}

# ── rclone ────────────────────────────────────────────────────────────────────
if (Get-Command rclone -ErrorAction SilentlyContinue) {
    $v = rclone --version 2>&1 | Select-Object -First 1
    Log-Ok "rclone $v"
} else {
    Log-Warn "rclone not found — installing via winget"
    winget install -e --id Rclone.Rclone --accept-source-agreements --accept-package-agreements
    Log-Ok "rclone installed"
}

# ── rclone remote check ───────────────────────────────────────────────────────
Write-Host ""
$remotes = rclone listremotes 2>$null
if ($remotes -match "gdrive:") {
    Log-Ok "rclone remote 'gdrive' already configured"
} else {
    Log-Warn "rclone remote 'gdrive' not configured"
    Write-Host "  Run: rclone config"
    Write-Host "  Create a new remote named 'gdrive' of type 'drive' (Google Drive)"
    Write-Host "  See: https://rclone.org/drive/"
}

Write-Host ""
Log-Ok "All dependencies satisfied. You can now run .\install.ps1"
