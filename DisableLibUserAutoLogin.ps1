# Windows 11 Pro - Disable LibUser Autologin Script
# This script disables automatic login for LibUser
# Requires Administrator privileges

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to write log entries
function Write-LogEntry {
    param([string]$Message)
    
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $logFile = Join-Path $scriptDir "DisableLibUserAutoLogin.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    # Write to log file
    $logEntry | Out-File $logFile -Append -Force
    
    # Also display on screen
    Write-Host $Message -ForegroundColor Green
}

# Function to display current autologin status
function Get-AutoLoginStatus {
    try {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        
        # Check if registry path exists
        if (-not (Test-Path $registryPath)) {
            Write-Host "Registry path $registryPath does not exist." -ForegroundColor Red
            return $null
        }
        
        $autoAdminLogon = Get-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
        $defaultUserName = Get-ItemProperty -Path $registryPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
        
        if ($autoAdminLogon -and $autoAdminLogon.AutoAdminLogon -eq "1") {
            if ($defaultUserName -and $defaultUserName.DefaultUserName) {
                Write-Host "Autologin is ENABLED for user: $($defaultUserName.DefaultUserName)" -ForegroundColor Yellow
                return @{
                    Enabled = $true
                    Username = $defaultUserName.DefaultUserName
                }
            } else {
                Write-Host "Autologin is ENABLED but no default user set" -ForegroundColor Yellow
                return @{
                    Enabled = $true
                    Username = $null
                }
            }
        } else {
            Write-Host "Autologin is DISABLED" -ForegroundColor Green
            return @{
                Enabled = $false
                Username = $null
            }
        }
    }
    catch {
        Write-Host "Could not determine autologin status: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to disable autologin
function Disable-AutoLogin {
    try {
        Write-Host "Disabling autologin..." -ForegroundColor Yellow
        
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        
        # Disable autologin
        Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "0" -Type String -ErrorAction Stop
        Write-Host "Set AutoAdminLogon = 0" -ForegroundColor Green
        
        # Remove the default password (security best practice)
        Remove-ItemProperty -Path $registryPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
        Write-Host "Removed DefaultPassword registry value" -ForegroundColor Green
        
        # Optionally remove DefaultUserName (uncomment if desired)
        # Remove-ItemProperty -Path $registryPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
        
        Write-Host "Autologin disabled successfully." -ForegroundColor Green
        Write-LogEntry "Autologin disabled successfully."
        return $true
    }
    catch {
        Write-Host "Error disabling autologin: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogEntry "Error disabling autologin: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
Write-Host "Windows 11 Pro - Disable LibUser Autologin Script" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Check if running as Administrator
if (-not (Test-Administrator)) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

try {
    Write-Host "`nCurrent Status:" -ForegroundColor Cyan
    $currentStatus = Get-AutoLoginStatus
    
    if ($null -eq $currentStatus) {
        Write-Host "Could not determine autologin status. Exiting." -ForegroundColor Red
        exit 1
    }
    
    if (-not $currentStatus.Enabled) {
        Write-Host "`nAutologin is already disabled. No action needed." -ForegroundColor Green
        Write-LogEntry "Autologin already disabled - no action taken."
    }
    else {
        Write-Host "`nDisabling autologin for: $($currentStatus.Username)" -ForegroundColor Yellow
        
        if (Disable-AutoLogin) {
            Write-Host "`nNew Status:" -ForegroundColor Cyan
            Get-AutoLoginStatus
            Write-Host "`nUsers will now be required to select an account and enter credentials at login." -ForegroundColor Green
        }
        else {
            Write-Host "Failed to disable autologin." -ForegroundColor Red
            exit 1
        }
    }
    
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $logFile = Join-Path $scriptDir "DisableLibUserAutoLogin.log"
    Write-Host "`nLog file location: $logFile" -ForegroundColor Cyan
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-LogEntry "Error: $($_.Exception.Message)"
    exit 1
}

# Example usage:
<#
# Simple usage - no parameters needed
.\DisableLibUserAutoLogin.ps1

# Script behavior:
# - Checks current autologin status
# - If autologin is enabled: Disables it and removes password from registry
# - If autologin is already disabled: Reports status and exits
# - Creates log file 'DisableLibUserAutoLogin.log' next to the script

# After running this script:
# - Windows will show the login screen on startup
# - Users must manually select their account and enter credentials

# To re-enable autologin:
# - Run CreateLibUser.ps1 again
#>