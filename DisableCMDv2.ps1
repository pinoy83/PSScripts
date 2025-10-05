<#
.SYNOPSIS
    Disable Command Prompt for a Local User using direct registry manipulation
.DESCRIPTION
    Simple script to disable command prompt for a specific user by directly
    modifying their registry using reg.exe commands
.PARAMETER TargetUser
    Username to disable command prompt for
.PARAMETER Enable
    Switch to enable command prompt instead of disabling it
.EXAMPLE
    .\DisableCMDv2.ps1 -TargetUser "TUser"
    Disables Command Prompt for TUser
.EXAMPLE
    .\DisableCMDv2.ps1 -TargetUser "TUser" -Enable
    Enables Command Prompt for TUser
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TargetUser,
    
    [switch]$Enable
)

# Ensure running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Configuration
$PolicyValue = if ($Enable) { 0 } else { 2 }  # 0=Enable, 2=Disable
$Action = if ($Enable) { "Enabling" } else { "Disabling" }

function Get-UserSID {
    param([string]$Username)
    try {
        $user = Get-LocalUser -Name $Username -ErrorAction Stop
        return $user.SID.Value
    }
    catch {
        throw "User '$Username' not found: $($_.Exception.Message)"
    }
}

function Get-UserProfilePath {
    param([string]$SID)
    try {
        $profilePath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID" -Name ProfileImagePath -ErrorAction SilentlyContinue
        if ($profilePath) {
            return $profilePath.ProfileImagePath
        }
        return "C:\Users\$TargetUser"
    }
    catch {
        throw "Could not find profile path: $($_.Exception.Message)"
    }
}

function Test-HiveLoaded {
    param([string]$SID)
    $result = & reg.exe query "HKU\$SID" 2>&1
    return $LASTEXITCODE -eq 0
}

Write-Host "Command Prompt Policy Manager (v2)" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Target User: $TargetUser" -ForegroundColor White
Write-Host "Action: $Action Command Prompt" -ForegroundColor White
Write-Host ""

# Step 1: Get the user SID
Write-Host "Step 1: Resolving user SID..." -ForegroundColor Yellow
try {
    $userSID = Get-UserSID -Username $TargetUser
    Write-Host "User SID: $userSID" -ForegroundColor Green
}
catch {
    Write-Error "Failed to get user SID: $_"
    exit 1
}

# Step 2: Check if the hive is already loaded
Write-Host "Step 2: Checking if user hive is loaded..." -ForegroundColor Yellow
$hiveLoaded = Test-HiveLoaded -SID $userSID
$hiveMountedByScript = $false

# Step 3: Mount the hive if not loaded
if (-not $hiveLoaded) {
    Write-Host "User hive not loaded, need to mount it." -ForegroundColor Yellow
    $profilePath = Get-UserProfilePath -SID $userSID
    Write-Host "User profile path: $profilePath" -ForegroundColor Cyan
    $ntUserDat = Join-Path $profilePath "NTUSER.DAT"
    
    if (-not (Test-Path $ntUserDat)) {
        Write-Error "NTUSER.DAT not found at: $ntUserDat"
        exit 1
    }
    
    Write-Host "Mounting user hive..." -ForegroundColor Yellow
    $result = & reg.exe load "HKU\$userSID" $ntUserDat 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to mount user hive: $result"
        exit 1
    }
    $hiveMountedByScript = $true
    Write-Host "Successfully mounted user hive" -ForegroundColor Green
}
else {
    Write-Host "User hive is already loaded" -ForegroundColor Green
}

# Step 4: Check current policy value
Write-Host "Step 4: Checking current policy..." -ForegroundColor Yellow
$regQuery = & reg.exe query "HKU\$userSID\Software\Policies\Microsoft\Windows\System" /v DisableCMD 2>&1
$currentValue = if ($LASTEXITCODE -eq 0) {
    if ($regQuery -match "0x(\d)") {
        [int]$Matches[1]
    }
    else {
        "Unknown format"
    }
}
else {
    "Not set"
}

$currentStatus = switch ($currentValue) {
    0 { "Enabled" }
    1 { "Disabled (batch files allowed)" }
    2 { "Disabled (completely)" }
    default { $currentValue }
}
Write-Host "Current CMD Status: $currentStatus" -ForegroundColor Cyan

# Step 5: Set the policy
Write-Host "Step 5: $Action command prompt..." -ForegroundColor Yellow
$regPath = "HKU\$userSID\Software\Policies\Microsoft\Windows\System"

# Create the path if it doesn't exist
$checkPath = & reg.exe query $regPath 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating registry path..." -ForegroundColor Yellow
    & reg.exe add $regPath /f | Out-Null
}

# Set the policy
$result = & reg.exe add $regPath /v DisableCMD /t REG_DWORD /d $PolicyValue /f 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS: Command prompt has been $(if ($Enable) {"enabled"} else {"disabled"}) for user $TargetUser" -ForegroundColor Green
} else {
    Write-Error "Failed to set registry value: $result"
}

# Step 6: Unmount the hive if we mounted it
if ($hiveMountedByScript) {
    Write-Host "Step 6: Unmounting user hive..." -ForegroundColor Yellow
    
    # Try up to 5 times to unmount the hive
    $maxTries = 5
    $try = 1
    $unloaded = $false
    
    while (-not $unloaded -and $try -le $maxTries) {
        Start-Sleep -Milliseconds 500
        $result = & reg.exe unload "HKU\$userSID" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully unmounted user hive" -ForegroundColor Green
            $unloaded = $true
        }
        else {
            Write-Host "Unmount attempt $try failed: $result" -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            $try++
        }
    }
    
    if (-not $unloaded) {
        Write-Warning "Could not unmount hive after $maxTries attempts. You may need to reboot to release the hive."
    }
}
else {
    Write-Host "Step 6: Skipping unmount (hive was already loaded)" -ForegroundColor Cyan
}

Write-Host "`nOperation completed!" -ForegroundColor Green