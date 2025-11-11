<#
.SYNOPSIS
    Disable Command Prompt for Specific User (Non-Domain Workgroup)

.DESCRIPTION
    Disables Command Prompt access for a specified local user by modifying their registry hive.
    Can run without the target user being logged in by loading their NTUSER.DAT file.
    Creates Windows Event Log entries for audit trail.

.PARAMETER TargetUser
    The local username to disable Command Prompt for

.PARAMETER Enable
    Switch to enable Command Prompt (reverse the disable action)

.PARAMETER LogSource
    Custom event log source name (default: CMDPolicyManager)

.EXAMPLE
    .\DisableCMD.ps1 -TargetUser "TUser"
    Disables Command Prompt for user TUser

.EXAMPLE
    .\DisableCMD.ps1 -TargetUser "TUser" -Enable
    Re-enables Command Prompt for user TUser

.NOTES
    Author: GitHub Copilot
    Version: 1.1
    Created: October 2025

    Requirements:
    - Run as Administrator
    - PowerShell 5.1+
    - Windows 10/11 workgroup machine

    Registry Policy Applied:
    HKCU\Software\Policies\Microsoft\Windows\System\DisableCMD = 2 (disable completely)

    Event Log Details:
    - Log: Application
    - Source: CMDPolicyManager
    - Event IDs: 1001 (Success), 1002 (Error), 1003 (Info)
#>

<#
...existing comment block...
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$TargetUser,

    [switch]$Enable,

    [string]$LogSource = 'CMDPolicyManager'
)

# Requires elevation
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Configuration
$PolicyRegPath = 'Software\Policies\Microsoft\Windows\System'
$PolicyName = 'DisableCMD'
$DisableValue = 2  # 0=Enable, 1=Disable but allow batch files, 2=Disable completely
$EnableValue = 0

#region Event Logging Functions
function Initialize-EventLogSource {
    param([string]$Source)

    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
            New-EventLog -LogName Application -Source $Source
            Write-Host "Created event log source: $Source" -ForegroundColor Green
        }
        return $true
    }
    catch {
        Write-Warning "Could not create event log source '$Source': $($_.Exception.Message)"
        return $false
    }
}

function Write-CMDPolicyEvent {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][int]$EventId,
        [ValidateSet('Information','Warning','Error')][string]$EntryType = 'Information',
        [string]$Source = $LogSource
    )

    try {
        if ([System.Diagnostics.EventLog]::SourceExists($Source)) {
            Write-EventLog -LogName Application -Source $Source -EntryType $EntryType -EventId $EventId -Message $Message
            Write-Host "Event logged: ID $EventId - $Message" -ForegroundColor Cyan
        }
        else {
            Write-Warning "Event log source '$Source' not available. Message: $Message"
        }
    }
    catch {
        Write-Warning "Failed to write event log: $($_.Exception.Message)"
    }
}
#endregion

#region User and Registry Functions
function Test-HKUDRIVE {
    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        Write-Host "HKU: drive not found. Creating HKU: drive..." -ForegroundColor Yellow
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
        Start-Sleep -Milliseconds 500
        Write-Host "HKU: drive created." -ForegroundColor Green
    } else {
        Write-Host "HKU: drive already exists." -ForegroundColor Cyan
    }
}

function Reset-HKUDRIVE {
    if (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue) {
        Write-Host "Removing HKU: drive for refresh..." -ForegroundColor Yellow
        Remove-PSDrive -Name HKU -Force
        Start-Sleep -Milliseconds 500
    }
    Write-Host "Re-creating HKU: drive..." -ForegroundColor Yellow
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
    Start-Sleep -Milliseconds 500
    Write-Host "HKU: drive refreshed." -ForegroundColor Green
}
function Get-UserSID {
    param([Parameter(Mandatory)][string]$Username)

    try {
        $user = Get-LocalUser -Name $Username -ErrorAction Stop
        return $user.SID.Value
    }
    catch {
        throw "User '$Username' not found on this system: $($_.Exception.Message)"
    }
}

function Get-UserProfilePath {
    param([Parameter(Mandatory)][string]$SID)

    try {
        # Try to get profile path from registry
        $profilePath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID" -Name ProfileImagePath -ErrorAction SilentlyContinue

        if ($profilePath) {
            return $profilePath.ProfileImagePath
        }

        # Fallback: construct typical path
        $username = (Get-LocalUser | Where-Object { $_.SID.Value -eq $SID }).Name
        return "C:\Users\$username"
    }
    catch {
        throw "Could not determine profile path for SID $SID`: $($_.Exception.Message)"
    }
}

function Test-UserHiveLoaded {
    param([Parameter(Mandatory)][string]$SID)
    $isLoaded = Test-Path "HKU:\$SID"
    if ($isLoaded) {
        Write-Host "User hive for SID $SID is already loaded (user may be logged in)." -ForegroundColor Cyan
    } else {
        Write-Host "User hive for SID $SID is NOT loaded (user likely not logged in)." -ForegroundColor Yellow
    }
    return $isLoaded
}

function Mount-UserHive {
    param(
        [Parameter(Mandatory)][string]$SID,
        [Parameter(Mandatory)][string]$ProfilePath
    )

    $ntUserDat = Join-Path $ProfilePath "NTUSER.DAT"

    if (-not (Test-Path $ntUserDat)) {
        throw "NTUSER.DAT not found at: $ntUserDat"
    }

    try {
        Write-Host "Bouncing HKU PSDrive to ensure fresh state..." -ForegroundColor Yellow
        Reset-HKUDRIVE
        Write-Host "Attempting to mount user hive for SID $SID from $ntUserDat ..." -ForegroundColor Yellow
        $result = & reg.exe load "HKU\$SID" $ntUserDat 2>&1
        Write-Host "reg.exe output:` $result" -ForegroundColor Magenta

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to load user hive: $($result -join ' ')"
        }

        Write-Host "Successfully loaded user hive for SID: $SID" -ForegroundColor Green
        return $true
    }
    catch {
        throw "Error mounting user hive: $($_.Exception.Message)"
    }
}

function Dismount-UserHive {
    param([Parameter(Mandatory)][string]$SID)
    $maxTries = 5
    $try = 1
    while ($try -le $maxTries) {
        Start-Sleep -Milliseconds 500
        $result = & reg.exe unload "HKU\$SID" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully unloaded user hive for SID: $SID" -ForegroundColor Green
            return
        } elseif ($result -join ' ' -match 'The system was unable to unload the registry hive') {
            Write-Warning "Hive still in use, retrying ($try/$maxTries)..."
            Start-Sleep -Seconds 1
            $try++
        } else {
            Write-Warning "Failed to unload user hive: $($result -join ' ')"
            break
        }
    }
    if ($try -gt $maxTries) {
        Write-Warning "Could not unload user hive after $maxTries attempts."
    }
}

function Set-CMDPolicy {
    param(
        [Parameter(Mandatory)][string]$SID,
        [Parameter(Mandatory)][int]$PolicyValue,
        [Parameter(Mandatory)][string]$Action
    )

    $regPath = "HKU\$SID\$PolicyRegPath"

    try {
        Write-Host "Set-CMDPolicy: Setting $PolicyName via reg.exe at $regPath..." -ForegroundColor Yellow

        # Add / create the key/value using reg.exe
        $addResult = & reg.exe add $regPath /v $PolicyName /t REG_DWORD /d $PolicyValue /f 2>&1
        Write-Host "Set-CMDPolicy: reg.exe add output: $($addResult -join ' ')" -ForegroundColor Magenta

        if ($LASTEXITCODE -ne 0) {
            throw "reg.exe add failed: $($addResult -join ' ')"
        }

        # Verify the value with reg.exe query
        $queryResult = & reg.exe query $regPath /v $PolicyName 2>&1
        Write-Host "Set-CMDPolicy: reg.exe query output: $($queryResult -join ' ')" -ForegroundColor Magenta

        if ($LASTEXITCODE -ne 0) {
            throw "reg.exe query failed: $($queryResult -join ' ')"
        }

        $queryText = $queryResult -join ' '
        if ($queryText -match '0x([0-9A-Fa-f]+)') {
            $hex = $Matches[1]
            $actual = [convert]::ToInt32($hex,16)
            if ($actual -eq $PolicyValue) {
                $message = "$Action Command Prompt policy for user SID: $SID (Value: $PolicyValue)"
                Write-Host $message -ForegroundColor Green
                Write-CMDPolicyEvent -Message $message -EventId 1001 -EntryType Information
                Write-Host "Set-CMDPolicy: SUCCESS" -ForegroundColor Green
                return $true
            }
            else {
                $failMsg = "Policy verification failed. Expected: $PolicyValue, Got: $actual"
                Write-Host "Set-CMDPolicy: FAILURE - $failMsg" -ForegroundColor Red
                Write-CMDPolicyEvent -Message $failMsg -EventId 1002 -EntryType Error
                return $false
            }
        }
        else {
            throw "Policy verification failed: unexpected reg.exe output: $queryText"
        }
    }
    catch {
        $errorMsg = "Set-CMDPolicy: EXCEPTION - Failed to $Action Command Prompt policy for SID $SID`: $($_.Exception.Message)"
        Write-Host $errorMsg -ForegroundColor Red
        Write-Error $errorMsg
        Write-CMDPolicyEvent -Message $errorMsg -EventId 1002 -EntryType Error
        return $false
    }
}

function Get-CurrentCMDPolicy {
    param([Parameter(Mandatory)][string]$SID)
    $regPath = "HKU:\$SID\$PolicyRegPath"

    try {
        if (Test-Path $regPath) {
            $policy = Get-ItemProperty -Path $regPath -Name $PolicyName -ErrorAction SilentlyContinue
            if ($policy) {
                return $policy.$PolicyName
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

# At the start of your script, before any HKU: usage:
Test-HKUDRIVE

#endregion

#region Main Execution
function Main {
    Write-Host "Command Prompt Policy Manager" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "Target User: $TargetUser" -ForegroundColor White
    Write-Host "Action: $(if ($Enable) { 'Enable' } else { 'Disable' }) Command Prompt" -ForegroundColor White
    Write-Host ""

    # Initialize event logging
    Initialize-EventLogSource -Source $LogSource

    try {
        # Get user SID
        Write-Host "Resolving user SID..." -ForegroundColor Yellow
        $userSID = Get-UserSID -Username $TargetUser
        Write-Host "User SID: $userSID" -ForegroundColor Green

        # Get profile path
        Write-Host "Determining profile path..." -ForegroundColor Yellow
        $profilePath = Get-UserProfilePath -SID $userSID
        Write-Host "Profile path: $profilePath" -ForegroundColor Green

        # Check if user hive is already loaded
        $hiveWasLoaded = Test-UserHiveLoaded -SID $userSID
        $hiveMountedByScript = $false

        if (-not $hiveWasLoaded) {
            Write-Host "User hive not loaded, mounting..." -ForegroundColor Yellow
            Reset-HKUDRIVE
            Mount-UserHive -SID $userSID -ProfilePath $profilePath
            $hiveMountedByScript = $true
        }
        else {
            Write-Host "User hive already loaded" -ForegroundColor Green
        }

        #Ensure Hive is loaded
        Test-UserHiveLoaded -SID $userSID
        # Ensure HKU drive after mounting
        Test-HKUDRIVE

        # Check current policy status
        Reset-HKUDRIVE
        $currentPolicy = Get-CurrentCMDPolicy -SID $userSID
        $currentStatus = switch ($currentPolicy) {
            0 { "Enabled" }
            1 { "Disabled (batch files allowed)" }
            2 { "Disabled (completely)" }
            $null { "Not Set" }
            default { "Unknown ($currentPolicy)" }
        }

        Write-Host "Current CMD Policy Status: $currentStatus" -ForegroundColor Cyan

        # Apply the policy
        $targetValue = if ($Enable) { $EnableValue } else { $DisableValue }
        $action = if ($Enable) { "Enabled" } else { "Disabled" }

        Write-Host "Applying policy..." -ForegroundColor Yellow

        if (Set-CMDPolicy -SID $userSID -PolicyValue $targetValue -Action $action) {
            Write-Host "SUCCESS: Command Prompt $action for user '$TargetUser'" -ForegroundColor Green

            # Log summary event
            $summaryMsg = "Command Prompt policy changed for user '$TargetUser' (SID: $userSID). Previous: $currentStatus, New: $action"
            Write-CMDPolicyEvent -Message $summaryMsg -EventId 1003 -EntryType Information
        }
        else {
            Write-Host "FAILED: Could not apply Command Prompt policy" -ForegroundColor Red
            exit 1
        }
    }
    catch {
        $errorMsg = "Script execution failed: $($_.Exception.Message)"
        Write-Error $errorMsg
        Write-CMDPolicyEvent -Message $errorMsg -EventId 1002 -EntryType Error
        exit 1
    }
finally {
    # Clean up: dismount hive if we mounted it
    if ($hiveMountedByScript -and $userSID) {
        Write-Host "Cleaning up user hive..." -ForegroundColor Yellow
        Dismount-UserHive -SID $userSID
        # Write-Host "Dismounting user hive... Not Really..." -ForegroundColor Yellow
    } else {
        Write-Host "Hive was not mounted by script, skipping dismount." -ForegroundColor Cyan
    }
}   

    Write-Host ""
    Write-Host "Operation completed successfully!" -ForegroundColor Green
    Write-Host "Check Event Viewer > Windows Logs > Application for detailed logs (Source: $LogSource)" -ForegroundColor Cyan
}

# Execute main function
Main
#endregion