<#
.SYNOPSIS
    Angular Version Manager (AVM) Installer v1
    
.DESCRIPTION
    Installs/Updates 'avm' in the PowerShell profile.

.NOTES
    File Name      : install_avm.ps1
    Prerequisite   : NVM for Windows
    License        : MIT
#>

# =============================================================================
# 1. PERMISSION CHECK
# =============================================================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[INIT] Requesting Administrator privileges..." -ForegroundColor Yellow
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $processInfo.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($processInfo)
    } catch {
        Write-Error "Failed to elevate permissions. Please run as Administrator."
    }
    exit
}

# =============================================================================
# 2. DEFINE CORE LOGIC (Syntax Fixed)
# =============================================================================
$AvmScriptContent = @'

#region AVM_MANAGER
# -----------------------------------------------------------------------------
#  ANGULAR VERSION MANAGER (AVM)
#  Automates switching between Angular versions by orchestrating NVM and NPM.
#  Author: Rakesh R (https://github.com/officialrakeshr)
#  Tool: Google Gemini
#  Map Source: https://angular.dev/reference/versions
# -----------------------------------------------------------------------------
function avm {
    param (
        [Parameter(Mandatory=$true, HelpMessage="The target Angular version (e.g., 16, 17, 18.2.0)")]
        [string]$Version
    )

    # --- CONFIGURATION ---
    $FallbackNodeVer = "22" 

    # Mapping: Angular Major -> Recommended Node.js Version
    # Updated: Jan 2026
    $NodeMap = @{
        "21" = "24"; "20" = "22"; "19" = "22"
        "18" = "20"; "17" = "20"; "16" = "18"; "15" = "18"; "14" = "16"
        "13" = "16"; "12" = "14"; "11" = "12"; "10" = "12"; "9"  = "12"
        "8"  = "10"; "7"  = "10"; "6"  = "8"; "5"  = "8";  "4"  = "6"
    }

    # --- INPUT SANITIZATION ---
    $Version = $Version.Trim()

    if ($Version -match "\.") {
        $AngularMajor = $Version.Split('.')[0]
        $IsSpecific = $true
    } else {
        $AngularMajor = $Version
        $IsSpecific = $false
    }

    $TargetNodeMajor = $NodeMap[$AngularMajor]

    if ($null -eq $TargetNodeMajor) {
        Write-Host "[WARN] Angular v$AngularMajor is not defined in the compatibility map." -ForegroundColor Yellow
        Write-Host "       Defaulting to Node v$FallbackNodeVer. Proceed? (Y/N)"
        if ((Read-Host) -notmatch "^[Yy]$") { return }
        $TargetNodeMajor = $FallbackNodeVer
    }
    
    # Clean whitespace to prevent URL parsing errors in NVM
    $TargetNodeMajor = "$TargetNodeMajor".Trim()

    Write-Host "[AVM] Request: Angular v$Version requires Node v$TargetNodeMajor.x" -ForegroundColor Cyan

    # --- STEP 1: NVM SWITCHING ---
    # Pipe to Out-String to ensure we get a text blob, not an array
    $nvmOutputRaw = nvm list | Out-String
    $pattern = "\b($TargetNodeMajor\.\d+\.\d+)\b"

    if ($nvmOutputRaw -match $pattern) {
        $BestLocalNode = $Matches[1].Trim()
        $CurrentNode = node -v 2>$null
        if ($CurrentNode -ne "v$BestLocalNode") {
            Write-Host "[AVM] Switching to local Node version $BestLocalNode..."
            nvm use $BestLocalNode
        }
    } else {
        Write-Host "[AVM] Node v$TargetNodeMajor.x not found locally. Installing..." -ForegroundColor Yellow
        nvm install "$TargetNodeMajor"
        nvm use "$TargetNodeMajor"
    }

    if ($LASTEXITCODE -ne 0) { 
        Write-Error "Failed to switch Node version. Ensure NVM is installed correctly."
        return 
    }

    # --- STEP 2: ANGULAR CLI MANAGEMENT ---
    $npmOutput = npm list -g @angular/cli --depth=0 --json 2>$null | ConvertFrom-Json 
    $InstalledFull = if ($npmOutput.dependencies.'@angular/cli') { 
        $npmOutput.dependencies.'@angular/cli'.version 
    } else { $null }

    $NeedsInstall = $false

    if (-not $InstalledFull) {
        Write-Host "[AVM] Angular CLI not found in this Node environment." -ForegroundColor Yellow
        $NeedsInstall = $true
    } else {
        if ($IsSpecific -and $InstalledFull -ne $Version) { $NeedsInstall = $true }
        elseif (-not $IsSpecific -and $InstalledFull.Split('.')[0] -ne $AngularMajor) { $NeedsInstall = $true }
    }

    if ($NeedsInstall) {
        if ($InstalledFull) { 
            Write-Host "[AVM] Removing incompatible version (v$InstalledFull)..." -ForegroundColor Gray
            npm uninstall -g @angular/cli
        }
        Write-Host "[AVM] Installing @angular/cli@$Version..." -ForegroundColor Cyan
        npm install -g @angular/cli@$Version
        Write-Host "[SUCCESS] Installed Angular CLI v$Version" -ForegroundColor Green
    } else {
        Write-Host "[SUCCESS] Ready! Using Node $(node -v) and Angular CLI v$InstalledFull" -ForegroundColor Green
    }
}
#endregion AVM_MANAGER

'@

# =============================================================================
# 3. INSTALLATION
# =============================================================================
$ProfilePath = $PROFILE
Write-Host "[SETUP] Target Profile: $ProfilePath" -ForegroundColor Cyan

# Create profile if missing
if (-not (Test-Path $ProfilePath)) {
    Write-Host "        Creating new profile..." -ForegroundColor Yellow
    New-Item -Path $ProfilePath -Type File -Force | Out-Null
}

$CurrentContent = Get-Content -Path $ProfilePath -Raw -ErrorAction SilentlyContinue
if ($null -eq $CurrentContent) { $CurrentContent = "" }

# Check for existing installation to decide message
$RegionRegex = "(?ms)^\s*#region AVM_MANAGER.*?#endregion AVM_MANAGER\s*$"

if ($CurrentContent -match $RegionRegex) {
    Write-Host "[UPDATE] Correcting AVM version in profile..." -ForegroundColor Yellow
    $NewContent = $CurrentContent -replace $RegionRegex, $AvmScriptContent
} else {
    Write-Host "[INSTALL] Adding AVM to your PowerShell profile..." -ForegroundColor Green
    $NewContent = $CurrentContent + "`r`n`r`n" + $AvmScriptContent
}

Set-Content -Path $ProfilePath -Value $NewContent -Encoding UTF8

# =============================================================================
# 4. CONFIGURATION
# =============================================================================
Write-Host "[CONFIG] Setting Execution Policy..." -ForegroundColor Cyan
try {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "         Policy updated successfully." -ForegroundColor Green
} catch {
    Write-Host "         [Warning] Could not set policy automatically." -ForegroundColor Red
}

# =============================================================================
# 5. FINALIZATION
# =============================================================================
Write-Host "`n============================================" -ForegroundColor Green
Write-Host "      AVM INSTALLED SUCCESSFULLY " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

try {
    # Attempt to reload profile immediately
    . $PROFILE
    if (Get-Command "avm" -ErrorAction SilentlyContinue) {
        Write-Host " [SUCCESS] AVM is loaded! You can type 'avm 17' now." -ForegroundColor Cyan
    } else {
        throw "Reload verification failed"
    }
} catch {
    # If immediate reload fails (due to previous syntax error in profile), give clear instructions
    Write-Host "To start using AVM, please choose one option:"
    Write-Host " 1. Run this command: . `$PROFILE" -ForegroundColor Yellow
    Write-Host "    OR"
    Write-Host " 2. Close this window and open a new PowerShell session." -ForegroundColor Blue
}
Write-Host "`nHappy Angular development !!!"
Write-Host "`nPress Enter to exit AVM installation..."
Read-Host

