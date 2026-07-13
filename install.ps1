#Requires -Version 5.1
# install.ps1 — dotfiles installer for Windows
# Usage: .\install.ps1 [-Yes] [-SkipPrivate] [-DryRun]
# Note: Run as Administrator for symlink support (or enable Developer Mode)

[CmdletBinding()]
param(
    [switch]$Yes,          # Non-interactive: skip conflicts
    [switch]$SkipPrivate,  # Skip rclone private config pull
    [switch]$DryRun        # Show actions without executing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$DotfilesDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Manifest    = Join-Path $DotfilesDir "manifest.yaml"
$Hostname    = $env:COMPUTERNAME
$Platform    = "windows"

# ── Logging ───────────────────────────────────────────────────────────────────
function Log-Info  { param($msg) Write-Host "[dotfiles] $msg" -ForegroundColor White }
function Log-Ok    { param($msg) Write-Host "[✓] $msg" -ForegroundColor Green }
function Log-Warn  { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Log-Err   { param($msg) Write-Host "[✗] $msg" -ForegroundColor Red }
function Log-Step  { param($msg) Write-Host "[-] $msg" -ForegroundColor Cyan }

# ── Dependency check ──────────────────────────────────────────────────────────
function Check-Deps {
    $missing = @()
    if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) { $missing += "python3" }
    if (-not (Get-Command rclone  -ErrorAction SilentlyContinue)) { $missing += "rclone"  }
    if ($missing.Count -gt 0) {
        Log-Err "Missing dependencies: $($missing -join ', ')"
        Log-Err "Run: .\bin\install-deps.ps1"
        exit 1
    }
}

# ── Minimal YAML parsing via Python ───────────────────────────────────────────
function Parse-Manifest {
    $py = @"
import sys, re

manifest_path = sys.argv[1]
platform      = sys.argv[2]

with open(manifest_path) as f:
    content = f.read()

entries = re.split(r'\n  - name:', content)

for entry in entries[1:]:
    name_match   = re.match(r'\s*(\S+)', entry)
    public_match = re.search(r'public:\s*(true|false)', entry)
    repo_match   = re.search(r'repo_dir:\s*(\S+)', entry)
    priv_match   = re.search(r'private_dir:\s*(\S+)', entry)

    if not name_match:
        continue

    name   = name_match.group(1)
    public = public_match.group(1) == 'true' if public_match else True

    plat_section = re.search(r'platforms:(.*?)(?=\n  -|\Z)', entry, re.DOTALL)
    if not plat_section:
        continue
    plat_block = plat_section.group(1)
    target_match = re.search(rf'{platform}:\s*(\S+)', plat_block)
    if not target_match:
        continue

    target   = target_match.group(1)
    repo_dir = repo_match.group(1) if repo_match else ''
    priv_dir = priv_match.group(1) if priv_match else ''

    src = repo_dir if public else priv_dir
    print(f"{name}|{src}|{'public' if public else 'private'}|{target}")
"@

    $result = python3 -c $py $Manifest $Platform
    return $result -split "`n" | Where-Object { $_ -ne "" }
}

# ── Path expansion ────────────────────────────────────────────────────────────
function Expand-DotfilePath {
    param([string]$Path)
    $Path = $Path -replace '^\~', $env:USERPROFILE
    $Path = [System.Environment]::ExpandEnvironmentVariables($Path)
    return $Path
}

# ── Conflict prompt ───────────────────────────────────────────────────────────
function Prompt-Conflict {
    param([string]$Target, [string]$Src, [string]$Name)

    Write-Host ""
    Log-Warn "Conflict: $Target already exists"
    Log-Step "  Source:   $Src"
    Log-Step "  Existing: $(if (Test-Path $Target -PathType Container) { 'directory' } else { 'file' })"
    Write-Host ""
    Write-Host "  [s] Replace with junction/symlink (delete existing)"
    Write-Host "  [b] Backup existing, then symlink"
    Write-Host "  [k] Keep existing, skip"
    Write-Host "  [q] Quit installer"
    Write-Host ""

    $choice = Read-Host "  Choice [s/b/k/q]"
    switch ($choice.ToLower()) {
        "s" { return "replace" }
        "b" { return "backup"  }
        "k" { return "keep"    }
        "q" { return "quit"    }
        default { Log-Warn "Invalid choice, skipping."; return "keep" }
    }
}

# ── Symlink/Junction ──────────────────────────────────────────────────────────
function Do-Symlink {
    param([string]$Src, [string]$Target, [string]$Name)

    if (-not (Test-Path $Src)) {
        Log-Err "${Name}: source not found: $Src"
        return
    }

    $TargetExp = Expand-DotfilePath $Target

    # Already correct
    if (Test-Path $TargetExp) {
        $item = Get-Item $TargetExp -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $link = $item.Target
            if ($link -eq $Src) {
                Log-Ok "${Name}: already linked"
                return
            }
        }
    }

    # Conflict
    if (Test-Path $TargetExp) {
        if ($Yes) {
            Log-Warn "${Name}: conflict at $TargetExp — skipping (non-interactive)"
            return
        }
        $action = Prompt-Conflict -Target $TargetExp -Src $Src -Name $Name
        switch ($action) {
            "replace" {
                if ($DryRun) { Log-Step "[dry-run] Remove-Item $TargetExp -Recurse; New-Item junction"; return }
                Remove-Item $TargetExp -Recurse -Force
            }
            "backup" {
                $ts     = Get-Date -Format "yyyyMMddHHmmss"
                $backup = "${TargetExp}.bak.${ts}"
                if ($DryRun) { Log-Step "[dry-run] Rename-Item $TargetExp $backup; New-Item junction"; return }
                Rename-Item $TargetExp $backup
                Log-Ok "${Name}: backed up to $backup"
            }
            "keep" { Log-Step "${Name}: kept existing, skipped"; return }
            "quit" { Log-Info "Quitting."; exit 0 }
        }
    }

    if ($DryRun) { Log-Step "[dry-run] New-Item -ItemType Junction $TargetExp -> $Src"; return }

    $parent = Split-Path $TargetExp -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    # Use Junction for directories, SymbolicLink for files
    $srcItem = Get-Item $Src
    if ($srcItem.PSIsContainer) {
        New-Item -ItemType Junction -Path $TargetExp -Target $Src | Out-Null
    } else {
        New-Item -ItemType SymbolicLink -Path $TargetExp -Target $Src | Out-Null
    }
    Log-Ok "${Name}: linked $TargetExp -> $Src"
}

# ── Private config via rclone ─────────────────────────────────────────────────
function Pull-Private {
    $py = @"
import re
content = open(r'$Manifest').read()
remote = re.search(r'remote:\s*(\S+)', content)
path   = re.search(r'remote_path:\s*(\S+)', content)
print((remote.group(1) if remote else '') + '|' + (path.group(1) if path else ''))
"@
    $parts       = (python3 -c $py) -split '\|'
    $remote      = $parts[0]
    $remotePath  = $parts[1]
    $privateLocal = Join-Path $DotfilesDir ".private"

    Log-Info "Pulling private config via rclone (${remote}:${remotePath}) …"
    if ($DryRun) { Log-Step "[dry-run] rclone sync ${remote}:${remotePath} $privateLocal"; return $privateLocal }

    New-Item -ItemType Directory -Path $privateLocal -Force | Out-Null
    rclone sync "${remote}:${remotePath}" $privateLocal --progress
    if ($LASTEXITCODE -ne 0) {
        Log-Err "rclone sync failed — skipping private config"
        return ""
    }
    Log-Ok "Private config synced to $privateLocal"
    return $privateLocal
}

# ── Machine-local overrides ───────────────────────────────────────────────────
function Pull-MachineOverrides {
    param([string]$PrivateLocal)

    $machineDir = Join-Path $PrivateLocal "machines\$Hostname"
    if (-not (Test-Path $machineDir)) {
        Log-Warn "No machine-local overrides found for hostname '$Hostname' in Drive (machines\$Hostname\)"
        Log-Warn "Create machines\$Hostname in Drive if you want machine-specific config."
        return
    }

    Log-Info "Applying machine-local overrides for $Hostname …"
    Get-ChildItem -Path $machineDir -Recurse -File | ForEach-Object {
        $rel    = $_.FullName.Substring($machineDir.Length + 1)
        $target = Join-Path $env:USERPROFILE $rel
        Do-Symlink -Src $_.FullName -Target $target -Name "machine:$rel"
    }
}

# ── Main ──────────────────────────────────────────────────────────────────────
function Main {
    Check-Deps

    if ($DryRun) { Log-Warn "Dry-run mode — no changes will be made" }

    Log-Info "Platform: $Platform | Hostname: $Hostname"

    # Pull private config
    $privateLocal = ""
    if (-not $SkipPrivate) {
        $privateLocal = Pull-Private
        if ($privateLocal -eq "") { $SkipPrivate = $true }
    }

    # Process manifest entries
    Log-Info "Installing dotfiles …"
    foreach ($line in Parse-Manifest) {
        $parts      = $line -split '\|'
        $name       = $parts[0]
        $src        = $parts[1]
        $visibility = $parts[2]
        $target     = $parts[3]

        if ($visibility -eq "public") {
            $fullSrc = Join-Path $DotfilesDir $src
            Do-Symlink -Src $fullSrc -Target $target -Name $name
        } else {
            if ($SkipPrivate -or $privateLocal -eq "") {
                Log-Step "${name}: skipping private config"
                continue
            }
            $fullSrc = Join-Path $privateLocal $src
            Do-Symlink -Src $fullSrc -Target $target -Name $name
        }
    }

    # Machine overrides
    if ($privateLocal -ne "") {
        Pull-MachineOverrides -PrivateLocal $privateLocal
    }

    Log-Info "Done."
}

Main
