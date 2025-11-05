# Windows 11 Pro LibUser Creation and Autologin Configuration Script
# This script creates LibUser with a blank password and configures autologin
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
    $logFile = Join-Path $scriptDir "CreateLibUserScript.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    # Write to log file
    $logEntry | Out-File $logFile -Append -Force
    
    # Also display on screen
    Write-Host $Message -ForegroundColor Green
}

# Function to create LibUser account with blank password
function New-LibUser {
    try {
        Write-Host "Creating LibUser account with blank password..." -ForegroundColor Green
        
        # Create the user account with no password
        $newUser = New-LocalUser -Name "LibUser" -NoPassword -FullName "Library User" -Description "Limited user account for Public access."
        
        if ($newUser) {
            Write-Host "LibUser account created successfully (standard privileges, no password)." -ForegroundColor Green
            
            # Set password to never expire
            Set-LocalUser -Name "LibUser" -PasswordNeverExpires $true
            
            # Add LibUser to the Users security group
            try {
                Write-Host "Adding LibUser to Users security group..." -ForegroundColor Yellow
                Add-LocalGroupMember -Group "Users" -Member "LibUser" -ErrorAction Stop
                Write-Host "LibUser successfully added to Users group." -ForegroundColor Green
            }
            catch [Microsoft.PowerShell.Commands.MemberExistsException] {
                Write-Host "LibUser is already a member of Users group." -ForegroundColor Yellow
            }
            catch {
                Write-Host "Warning: Could not add LibUser to Users group: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "LibUser account created but may need manual group assignment." -ForegroundColor Yellow
            }
            
            return $true
        } else {
            Write-Host "Failed to create LibUser account." -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Error creating LibUser account: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to configure autologin for LibUser with blank password
function Set-AutoLogin {
    try {
        Write-Host "Configuring autologin for LibUser..." -ForegroundColor Green
        
        # Registry path for Winlogon
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        
        # Verify registry path exists
        if (-not (Test-Path $registryPath)) {
            Write-Host "Error: Registry path $registryPath does not exist." -ForegroundColor Red
            return $false
        }
        
        # Set autologin registry values with individual error handling
        try {
            Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "1" -Type String -ErrorAction Stop
            Write-Host "Set AutoAdminLogon = 1" -ForegroundColor Green
        }
        catch {
            throw "Failed to set AutoAdminLogon: $($_.Exception.Message)"
        }
        
        try {
            Set-ItemProperty -Path $registryPath -Name "DefaultUserName" -Value "LibUser" -Type String -ErrorAction Stop
            Write-Host "Set DefaultUserName = LibUser" -ForegroundColor Green
        }
        catch {
            throw "Failed to set DefaultUserName: $($_.Exception.Message)"
        }
        
        try {
            # Set blank password (empty string)
            Set-ItemProperty -Path $registryPath -Name "DefaultPassword" -Value "" -Type String -ErrorAction Stop
            Write-Host "Set DefaultPassword (blank)" -ForegroundColor Green
        }
        catch {
            throw "Failed to set DefaultPassword: $($_.Exception.Message)"
        }
        
        try {
            Set-ItemProperty -Path $registryPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME -Type String -ErrorAction Stop
            Write-Host "Set DefaultDomainName = $env:COMPUTERNAME" -ForegroundColor Green
        }
        catch {
            throw "Failed to set DefaultDomainName: $($_.Exception.Message)"
        }
        
        Write-Host "Autologin configured successfully for LibUser." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error configuring autologin: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to check if autologin is configured for LibUser
function Test-AutoLoginConfigured {
    try {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        
        # Check if registry path exists
        if (-not (Test-Path $registryPath)) {
            Write-Host "Warning: Registry path $registryPath does not exist." -ForegroundColor Yellow
            return $false
        }
        
        $autoAdminLogon = Get-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
        $defaultUserName = Get-ItemProperty -Path $registryPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
        
        return ($autoAdminLogon.AutoAdminLogon -eq "1" -and $defaultUserName.DefaultUserName -eq "LibUser")
    }
    catch {
        Write-Host "Error checking autologin status: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Function to disable autologin
function Disable-AutoLogin {
    try {
        Write-Host "Disabling autologin..." -ForegroundColor Yellow
        
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        
        Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "0" -Type String
        Remove-ItemProperty -Path $registryPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
        
        Write-Host "Autologin disabled successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error disabling autologin: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to display current autologin status
function Get-AutoLoginStatus {
    try {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        
        # Check if registry path exists
        if (-not (Test-Path $registryPath)) {
            Write-Host "Registry path $registryPath does not exist." -ForegroundColor Red
            return
        }
        
        $autoAdminLogon = Get-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
        $defaultUserName = Get-ItemProperty -Path $registryPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
        
        if ($autoAdminLogon -and $autoAdminLogon.AutoAdminLogon -eq "1") {
            if ($defaultUserName -and $defaultUserName.DefaultUserName) {
                Write-Host "Autologin is ENABLED for user: $($defaultUserName.DefaultUserName)" -ForegroundColor Green
            } else {
                Write-Host "Autologin is ENABLED but no default user set" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Autologin is DISABLED" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Could not determine autologin status: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution
Write-Host "Windows 11 Pro LibUser Setup Script" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Creates LibUser with blank password and configures autologin" -ForegroundColor Cyan

# Check if running as Administrator
if (-not (Test-Administrator)) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Set execution policy for current process
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Host "Execution policy set for current session." -ForegroundColor Green
}
catch {
    Write-Host "Warning: Could not modify execution policy." -ForegroundColor Yellow
}

try {
    # Check if LibUser exists
    $existingUser = Get-LocalUser -Name "LibUser" -ErrorAction SilentlyContinue
    
    if ($existingUser) {
        Write-Host "LibUser already exists." -ForegroundColor Yellow
        
        # Check if autologin is configured
        if (Test-AutoLoginConfigured) {
            $message = "LibUser exists and autologin is already configured. No changes needed."
            Write-LogEntry $message
        } else {
            Write-Host "Autologin not configured. Setting up autologin..." -ForegroundColor Yellow
            if (Set-AutoLogin) {
                Write-LogEntry "Autologin configured for existing LibUser account."
            }
        }
    } else {
        # Create LibUser
        if (New-LibUser) {
            Write-LogEntry "LibUser account created successfully with blank password."
            Write-Host "Setting up autologin..." -ForegroundColor Yellow
            if (Set-AutoLogin) {
                Write-LogEntry "Autologin configured for new LibUser account."
            }
        }
    }
    
    # Display final status
    Write-Host "`nFinal Status:" -ForegroundColor Cyan
    Get-AutoLoginStatus
    Write-Host "LibUser is configured as a standard (non-administrator) user with blank password." -ForegroundColor Green
    Write-Host "System will automatically login as LibUser on restart." -ForegroundColor Yellow
    
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $logFile = Join-Path $scriptDir "LibUserScript.log"
    Write-Host "`nLog file location: $logFile" -ForegroundColor Cyan
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Example usage:
<#
# Simple usage - no parameters needed
.\CreateLibUser.ps1

# Script behavior:
# - If LibUser doesn't exist: Creates LibUser with blank password and sets up autologin
# - If LibUser exists but no autologin: Sets up autologin  
# - If LibUser exists with autologin: Reports status to log file (no changes)

# Security note:
# - LibUser is created with a BLANK password
# - This is suitable for kiosk/library scenarios with physical access controls
# - Consider network security implications

# Log file:
# - 'LibUserScript.log' is created next to the script
# - Contains timestamps and actions performed

# To disable autologin later (run separately):
# .\DisableLibUserAutoLogin.ps1
#>