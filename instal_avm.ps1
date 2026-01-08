<#
.SYNOPSIS
    Angular Version Manager (AVM) Installer
    
.DESCRIPTION
    This script installs or updates the 'avm' function in the user's PowerShell profile.
    It automatically handles Administrator elevation, ExecutionPolicy, and 
    profile creation.

.NOTES
    File Name      : install_avm.ps1
    Prerequisite   : NVM for Windows (https://github.com/coreybutler/nvm-windows)
    License        : MIT
#>

# =============================================================================
# 1. AUTO-ELEVATION CHECK
# =============================================================================
# We need Admin rights to set ExecutionPolicy and ensure NVM switches correctly.
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[INIT] Requesting Administrator privileges to configure environment..." -ForegroundColor Yellow
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $processInfo.Verb = "runas"
    try {
        [System.Diagnostics.Process]::Start($processInfo)
    } catch {
        Write-Error "Failed to elevate permissions. Please run this script as Administrator."
    }
    exit
}

# =============================================================================
# 2. DEFINE THE AVM FUNCTION CONTENT
# =============================================================================
# This Here-String contains the actual logic that gets written to the user's profile.
$AvmScriptContent = @'

#region AVM_MANAGER
# -----------------------------------------------------------------------------
#  ANGULAR VERSION MANAGER (AVM)
#  Automates switching between Angular versions by orchestrating NVM and NPM.
#  Map Source: https://angular.dev/reference/versions
# -----------------------------------------------------------------------------
function avm {
    param (
        [Parameter(Mandatory=$true)]
        [HelpMessage="The target Angular version (e.g., 16, 17, 18.2.0)"]
        [string]$Version
    )

    # --- CONFIGURATION ---
    # Default fallback if the requested version is not in the map
    $FallbackNodeVer = "22" 

    # Mapping Angular Major Version -> Recommended Node.js Version
    # Updated: Jan 2026
    $NodeMap = @{
        # Future / Latest
        "21" = "24"
        "20" = "22"
        "19" = "22"

        # Modern (Ivy / Standalone)
        "18" = "20"
        "17" = "20"
        "16" = "18"
        "15" = "18"
        "14" = "16"

        # Legacy (ViewEngine)
        "13" = "16"; "12" = "14"; "11" = "12"
        "10" = "12"; "9"  = "12"
        "8"  = "10"; "7"  = "10"; "6"  = "8"
        "5"  = "8";  "4"  = "6"
    }

    # --- INPUT SANITIZATION ---
    $Version = $Version.Trim()

    # Determine if user requested a specific version (16.2.1) or major (16)
    if ($Version -match "\.") {
        $AngularMajor = $Version.Split('.')[0]
        $IsSpecific = $true
    } else {
        $AngularMajor = $Version
        $IsSpecific = $false
    }

    $TargetNodeMajor = $NodeMap[$AngularMajor]

    # Handle Unknown Versions
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
    
    # We pipe to Out-String to force a text blob. 
    # This prevents PowerShell from treating output as an array, which breaks regex matching.
    $nvmOutputRaw = nvm list | Out-String

    # Regex: Capture the full version string (e.g., 20.10.0) that matches the major version
    $pattern = "\b($TargetNodeMajor\.\d+\.\d+)\b"

    if ($nvmOutputRaw -match $pattern) {
        # Match found locally. $Matches[1] contains the capture group (exact version).
        $BestLocalNode = $Matches[1].Trim()
        
        $CurrentNode = node -v 2>$null
        if ($CurrentNode -ne "v$BestLocalNode") {
            Write-Host "[AVM] Switching to local Node version $BestLocalNode..."
            nvm use $BestLocalNode
        }
    } else {
        # No local match found. Install the major version.
        Write-Host "[AVM] Node v$TargetNodeMajor.x not found locally. Installing..." -ForegroundColor Yellow
        nvm install "$TargetNodeMajor"
        nvm use "$TargetNodeMajor"
    }

    # Verify NVM switch success
    if ($LASTEXITCODE -ne 0) { 
        Write-Error "Failed to switch Node version. Ensure NVM is installed correctly."
        return 
    }

    # --- STEP 2: ANGULAR CLI MANAGEMENT ---
    
    # We use -json to parse installed versions reliably without text scraping quirks
    $npmOutput = npm list -g @angular/cli --depth=0 --json 2>$null | ConvertFrom-Json 
    
    $InstalledFull = $null
    if ($npmOutput.dependencies.'@angular/cli') { 
        $InstalledFull = $npmOutput.dependencies.'@angular/cli'.version 
    }

    $NeedsInstall = $false

    if (-not $InstalledFull) {
        Write-Host "[AVM] Angular CLI not found in this Node environment." -ForegroundColor Yellow
        $NeedsInstall = $true
    } else {
        if ($IsSpecific -and $InstalledFull -ne $Version) { 
            # User wants 16.1.0, but has 16.2.0
            $NeedsInstall = $true 
        } elseif (-not $IsSpecific -and $InstalledFull.Split('.')[0] -ne $AngularMajor) { 
            # User wants 16, but has 17
            $NeedsInstall = $true 
        }
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
# 3. PROFILE INSTALLATION
# =============================================================================
# We target the standard current user profile ($PROFILE)
$ProfilePath = $PROFILE
Write-Host "[INSTALL] Target Profile: $ProfilePath" -ForegroundColor Cyan

# Create profile if it doesn't exist
if (-not (Test-Path $ProfilePath)) {
    Write-Host "          Profile not found. Creating..." -ForegroundColor Yellow
    New-Item -Path $ProfilePath -Type File -Force | Out-Null
}

$CurrentContent = Get-Content -Path $ProfilePath -Raw -ErrorAction SilentlyContinue
if ($null -eq $CurrentContent) { $CurrentContent = "" }

# Idempotency Check: Look for existing block to update instead of appending
$RegionRegex = "(?ms)^\s*#region AVM_MANAGER.*?#endregion AVM_MANAGER\s*$"

if ($CurrentContent -match $RegionRegex) {
    Write-Host "[INSTALL] Updating existing AVM version..." -ForegroundColor Yellow
    $NewContent = $CurrentContent -replace $RegionRegex, $AvmScriptContent
} else {
    Write-Host "[INSTALL] Adding AVM to profile..." -ForegroundColor Green
    $NewContent = $CurrentContent + "`r`n`r`n" + $AvmScriptContent
}

Set-Content -Path $ProfilePath -Value $NewContent -Encoding UTF8

# =============================================================================
# 4. ENVIRONMENT CONFIGURATION
# =============================================================================
Write-Host "[CONFIG]  Setting ExecutionPolicy to RemoteSigned..." -ForegroundColor Cyan
try {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "          Policy updated." -ForegroundColor Green
} catch {
    Write-Host "          [Warning] Could not set policy. You may need to do this manually." -ForegroundColor Red
}

# =============================================================================
# 5. COMPLETION
# =============================================================================
Write-Host "`n============================================" -ForegroundColor Green
Write-Host "       AVM INSTALLED SUCCESSFULLY " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# Try to reload immediately (works if user was already admin)
try {
    . $PROFILE
    if (Get-Command "avm" -ErrorAction SilentlyContinue) {
        Write-Host " [SUCCESS] AVM loaded! You can type 'avm 17' now." -ForegroundColor Cyan
    } else {
        throw "Reload check failed"
    }
} catch {
    # Fallback instructions if immediate reload fails due to process boundaries
    Write-Host "To start using AVM, please choose one option:"
    Write-Host " 1. Run this command: . `$PROFILE" -ForegroundColor Yellow
    Write-Host "    OR"
    Write-Host " 2. Close this window and open a new PowerShell session." -ForegroundColor Blue
}

Write-Host "`nPress Enter to exit..."
Read-Host
