<#
.SYNOPSIS
    Set per-user PowerShell ExecutionPolicy in a user's hive (LibUser).

.DESCRIPTION
    Loads the target user's NTUSER.DAT (if not already loaded), writes the
    ExecutionPolicy value under:
      HKU\<SID>\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell
    Uses reg.exe for all registry operations so it works reliably in a single session.

.PARAMETER TargetUser
    Local username to target (default: LibUser)

.PARAMETER Bypass
    If provided, sets ExecutionPolicy to "Bypass" instead of "RemoteSigned"

.NOTES
    Run as Administrator.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TargetUser = 'LibUser',

    [switch]$Bypass
)

# require elevation
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

$PolicyValue = if ($Bypass) { 'Bypass' } else { 'RemoteSigned' }
Write-Host "Target user: $TargetUser" -ForegroundColor Cyan
Write-Host "Desired ExecutionPolicy: $PolicyValue" -ForegroundColor Cyan

try {
    Write-Host "Resolving SID for user '$TargetUser'..." -ForegroundColor Yellow
    $user = Get-LocalUser -Name $TargetUser -ErrorAction Stop
    $SID = $user.SID.Value
    Write-Host "Found SID: $SID" -ForegroundColor Green
}
catch {
    Write-Error "Could not find local user '$TargetUser': $($_.Exception.Message)"
    exit 1
}

try {
    Write-Host "Determining profile path for SID $SID..." -ForegroundColor Yellow
    $profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID"
    $profilePath = (Get-ItemProperty -Path $profileKey -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
    Write-Host "Profile path: $profilePath" -ForegroundColor Green
}
catch {
    Write-Warning "Could not read profile path from registry, falling back to C:\Users\$TargetUser"
    $profilePath = "C:\Users\$TargetUser"
    Write-Host "Using fallback profile path: $profilePath" -ForegroundColor Yellow
}

$ntUserDat = Join-Path $profilePath 'NTUSER.DAT'
if (-not (Test-Path $ntUserDat)) {
    Write-Error "NTUSER.DAT not found at $ntUserDat"
    exit 1
}

function Test-HiveLoaded {
    param([string]$Sid)
    & reg.exe query "HKU\$Sid" > $null 2>&1
    return ($LASTEXITCODE -eq 0)
}


$hiveLoaded = Test-HiveLoaded -Sid $SID
$mountedByScript = $false

if ($hiveLoaded) {
    Write-Host "Hive for $SID already loaded (OS-level)." -ForegroundColor Cyan
} else {
    Write-Host "Hive for $SID not loaded. Attempting to load from $ntUserDat ..." -ForegroundColor Yellow
    $loadOut = & reg.exe load "HKU\$SID" $ntUserDat 2>&1
    Write-Host "reg.exe load output:`n$($loadOut -join "`n")" -ForegroundColor Magenta
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to load hive: $($loadOut -join ' ')"
        exit 1
    }
    Write-Host "Successfully loaded hive for $SID." -ForegroundColor Green
    $mountedByScript = $true
    Start-Sleep -Milliseconds 300
}

$regPath = "HKU\$SID\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell"
Write-Host "Ensuring registry key exists: $regPath" -ForegroundColor Yellow

# create key path (if missing)
$createOut = & reg.exe add $regPath /f 2>&1
Write-Host "reg.exe add (create path) output: $($createOut -join ' ')" -ForegroundColor Magenta
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create registry path: $($createOut -join ' ')"
    # proceed to cleanup if mounted by script
    if ($mountedByScript) {
        Write-Host "Attempting to unload hive due to failure..." -ForegroundColor Yellow
        & reg.exe unload "HKU\$SID" 2>&1 | Out-Null
    }
    exit 1
}

Write-Host "Setting ExecutionPolicy to '$PolicyValue' for SID $SID..." -ForegroundColor Yellow
$setOut = & reg.exe add $regPath /v ExecutionPolicy /t REG_SZ /d $PolicyValue /f 2>&1
Write-Host "reg.exe add (set value) output: $($setOut -join ' ')" -ForegroundColor Magenta
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set ExecutionPolicy: $($setOut -join ' ')"
    # cleanup below
}
else {
    # verify
    $queryOut = & reg.exe query $regPath /v ExecutionPolicy 2>&1
    Write-Host "reg.exe query output:`n$($queryOut -join "`n")" -ForegroundColor Magenta
    if ($LASTEXITCODE -eq 0 -and ($queryOut -join ' ') -match 'ExecutionPolicy\s+REG_SZ\s+(.*)$') {
        $actual = $Matches[1].Trim()
        Write-Host "Verified ExecutionPolicy = '$actual'" -ForegroundColor Green
    } else {
        Write-Warning "Verification failed or unexpected output; inspect reg.exe query output above."
    }
}

# Unload hive if we mounted it
if ($mountedByScript) {
    Write-Host "Attempting to unload hive for SID $SID..." -ForegroundColor Yellow
    $max = 5; $i = 1; $unloaded = $false
    while (-not $unloaded -and $i -le $max) {
        Start-Sleep -Milliseconds 400
        $unloadOut = & reg.exe unload "HKU\$SID" 2>&1
        Write-Host "reg.exe unload attempt $i output: $($unloadOut -join ' ')" -ForegroundColor Magenta
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully unloaded hive for $SID." -ForegroundColor Green
            $unloaded = $true
        } else {
            Write-Warning "Unload attempt $i failed: $($unloadOut -join ' ')"
            $i++
        }
    }
    if (-not $unloaded) {
        Write-Warning "Could not unload hive after $max attempts. A process may still hold the hive open."
    }
} else {
    Write-Host "Hive was not mounted by this script; leaving it loaded." -ForegroundColor Cyan
}

Write-Host "Operation completed." -ForegroundColor Green

