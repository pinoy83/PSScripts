# Windows 11 Pro - Delete LibUser Script
# This script removes the LibUser account and its profile silently
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
    
    $logFile = "C:\applications\DeleteLibUserScript.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    # Write to log file
    $logEntry | Out-File $logFile -Append -Force
}

# Function to delete LibUser account and profile
function Remove-LibUser {
    param([switch]$KeepProfile)
    
    try {
        # Check if LibUser exists
        $user = Get-LocalUser -Name "LibUser" -ErrorAction SilentlyContinue
        
        if (-not $user) {
            Write-LogEntry "LibUser account does not exist. Nothing to delete."
            return $false
        }
        
        Write-LogEntry "Found LibUser account."
        
        # Get the user's SID for profile deletion
        $sid = $user.SID.Value
        Write-LogEntry "User SID: $sid"
        
        # Delete the user account
        try {
            Write-LogEntry "Deleting LibUser account..."
            Remove-LocalUser -Name "LibUser" -ErrorAction Stop
            Write-LogEntry "LibUser account deleted successfully."
        }
        catch {
            Write-LogEntry "Error deleting LibUser account: $($_.Exception.Message)"
            return $false
        }
        
        # Delete the user profile unless -KeepProfile is specified
        if (-not $KeepProfile) {
            try {
                Write-LogEntry "Deleting LibUser profile..."
                
                # Check if profile exists
                $profile = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { $_.SID -eq $sid }
                
                if ($profile) {
                    Remove-CimInstance -InputObject $profile -ErrorAction Stop
                    Write-LogEntry "LibUser profile deleted successfully from $($profile.LocalPath)"
                }
                else {
                    Write-LogEntry "No profile found for LibUser (SID: $sid)."
                }
            }
            catch {
                Write-LogEntry "Warning: Could not delete LibUser profile - $($_.Exception.Message)"
            }
        }
        else {
            Write-LogEntry "LibUser account deleted but profile kept."
        }
        
        return $true
    }
    catch {
        Write-LogEntry "Error in Remove-LibUser: $($_.Exception.Message)"
        return $false
    }
}

# Function to disable autologin (if still configured)
function Clear-AutoLogin {
    try {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        
        # Check if registry path exists
        if (-not (Test-Path $registryPath)) {
            Write-LogEntry "Registry path does not exist. Skipping autologin cleanup."
            return
        }
        
        $autoAdminLogon = Get-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
        $defaultUserName = Get-ItemProperty -Path $registryPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
        
        # Only clear if it's set for LibUser
        if ($defaultUserName -and $defaultUserName.DefaultUserName -eq "LibUser") {
            Write-LogEntry "Clearing LibUser autologin settings..."
            
            Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "0" -Type String
            Remove-ItemProperty -Path $registryPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $registryPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $registryPath -Name "DefaultDomainName" -ErrorAction SilentlyContinue
            
            Write-LogEntry "Autologin settings cleared."
        }
        else {
            Write-LogEntry "Autologin is not configured for LibUser. No cleanup needed."
        }
    }
    catch {
        Write-LogEntry "Warning: Could not clear autologin settings - $($_.Exception.Message)"
    }
}

# Main execution
Write-LogEntry "=== DeleteLibUser Script Started ==="

# Check if running as Administrator
if (-not (Test-Administrator)) {
    Write-LogEntry "ERROR: This script requires Administrator privileges."
    exit 1
}

try {
    # Clear autologin settings first
    Clear-AutoLogin
    
    # Delete LibUser account and profile
    if (Remove-LibUser) {
        Write-LogEntry "LibUser deletion completed successfully."
    }
    else {
        Write-LogEntry "LibUser deletion completed with warnings."
    }
    
    Write-LogEntry "=== DeleteLibUser Script Completed ==="
}
catch {
    Write-LogEntry "Fatal error: $($_.Exception.Message)"
    exit 1
}

# Example usage:
<#
# Delete LibUser account and profile silently
.\DeleteLibUser.ps1

# The script will:
# 1. Clear autologin settings (if configured for LibUser)
# 2. Delete the LibUser account
# 3. Delete the LibUser profile and all associated data
# 4. Log all actions to C:\applications\DeleteLibUserScript.log
# 5. No user interaction required - runs completely silently

# What gets deleted:
# - User account
# - User profile folder (C:\Users\LibUser)
# - All user data (Desktop, Documents, Downloads, etc.)
# - MS Store apps installed by LibUser
# - Registry entries for the user
# - Autologin configuration

# Check the log file for results:
# C:\applications\DeleteLibUserScript.log
#>