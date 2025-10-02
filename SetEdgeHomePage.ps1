# Windows 11 Pro Edge Homepage Setter for LibUser
# This script sets Edge homepage specifically for LibUser account only
# Can be run remotely using System or Administrator account
# Requires Administrator privileges

# Function to check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to get LibUser SID
function Get-LibUserSID {
    try {
        $libUser = Get-LocalUser -Name "LibUser" -ErrorAction Stop
        $sid = $libUser.SID.Value
        return $sid
    }
    catch {
        Write-Host "Error: LibUser account not found." -ForegroundColor Red
        return $null
    }
}

# Function to write log entries
function Write-LogEntry {
    param([string]$Message)
    
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $logFile = Join-Path $scriptDir "EdgeHomepageSetter.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    # Write to log file
    $logEntry | Out-File $logFile -Append -Force
    
    # Also display on screen
    Write-Host $Message -ForegroundColor Green
}

# Function to set Edge homepage for LibUser
function Set-EdgeHomepageForLibUser {
    param([string]$HomepageURL)
    
    try {
        Write-Host "Setting Edge homepage for LibUser to: $HomepageURL" -ForegroundColor Yellow
        
        # Get LibUser SID
        $libUserSID = Get-LibUserSID
        if (-not $libUserSID) {
            return $false
        }
        
        Write-Host "Found LibUser SID: $libUserSID" -ForegroundColor Green
        
        # Registry paths for LibUser-specific Edge policies
        $registryPath = "HKU:\$libUserSID\Software\Policies\Microsoft\Edge"
        $startupURLsPath = "HKU:\$libUserSID\Software\Policies\Microsoft\Edge\RestoreOnStartupURLs"
        
        # Load LibUser registry hive if not already loaded
        $hiveMounted = $false
        if (-not (Test-Path "HKU:\$libUserSID")) {
            $libUserProfile = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.SID -eq $libUserSID }
            if ($libUserProfile -and $libUserProfile.LocalPath) {
                $ntUserDat = Join-Path $libUserProfile.LocalPath "NTUSER.DAT"
                if (Test-Path $ntUserDat) {
                    reg load "HKU\$libUserSID" "$ntUserDat" | Out-Null
                    $hiveMounted = $true
                    Write-Host "Loaded LibUser registry hive." -ForegroundColor Green
                }
            }
        }
        
        # Create the Edge policies registry path if it doesn't exist
        if (-not (Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            Write-Host "Created Edge policies registry path." -ForegroundColor Green
        }
        
        # Set the RestoreOnStartup policy to open specific URLs (4 = Open a list of URLs)
        Set-ItemProperty -Path $registryPath -Name "RestoreOnStartup" -Value 4 -PropertyType DWord -Force
        Write-Host "Set RestoreOnStartup policy to open specific URLs." -ForegroundColor Green
        
        # Create the startup URLs registry path if it doesn't exist
        if (-not (Test-Path $startupURLsPath)) {
            New-Item -Path $startupURLsPath -Force | Out-Null
            Write-Host "Created startup URLs registry path." -ForegroundColor Green
        }
        
        # Set the desired homepage URL
        Set-ItemProperty -Path $startupURLsPath -Name "1" -Value $HomepageURL -PropertyType String -Force
        Write-Host "Set homepage URL to: $HomepageURL" -ForegroundColor Green
        
        # Unload the hive if we mounted it
        if ($hiveMounted) {
            Start-Sleep -Seconds 2  # Give time for registry operations to complete
            reg unload "HKU\$libUserSID" | Out-Null
            Write-Host "Unloaded LibUser registry hive." -ForegroundColor Green
        }
        
        Write-Host "Edge homepage configured successfully for LibUser." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error setting Edge homepage for LibUser: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to check current Edge homepage for LibUser
function Get-LibUserEdgeHomepage {
    try {
        Write-Host "`nLibUser Edge Homepage Status:" -ForegroundColor Cyan
        
        # Get LibUser SID
        $libUserSID = Get-LibUserSID
        if (-not $libUserSID) {
            Write-Host "✗ LibUser account not found" -ForegroundColor Red
            return
        }
        
        # Check if LibUser hive is loaded
        $hiveMounted = $false
        if (-not (Test-Path "HKU:\$libUserSID")) {
            $libUserProfile = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.SID -eq $libUserSID }
            if ($libUserProfile -and $libUserProfile.LocalPath) {
                $ntUserDat = Join-Path $libUserProfile.LocalPath "NTUSER.DAT"
                if (Test-Path $ntUserDat) {
                    reg load "HKU\$libUserSID" "$ntUserDat" | Out-Null
                    $hiveMounted = $true
                }
            }
        }
        
        # Check LibUser-specific Edge settings
        $registryPath = "HKU:\$libUserSID\Software\Policies\Microsoft\Edge"
        $startupURLsPath = "HKU:\$libUserSID\Software\Policies\Microsoft\Edge\RestoreOnStartupURLs"
        
        $restorePolicy = Get-ItemProperty -Path $registryPath -Name "RestoreOnStartup" -ErrorAction SilentlyContinue
        $homepageURL = Get-ItemProperty -Path $startupURLsPath -Name "1" -ErrorAction SilentlyContinue
        
        if ($restorePolicy -and $restorePolicy.RestoreOnStartup -eq 4 -and $homepageURL) {
            Write-Host "✓ Edge Homepage configured: $($homepageURL.'1')" -ForegroundColor Green
        } else {
            Write-Host "✗ Edge Homepage not configured" -ForegroundColor Red
        }
        
        # Unload the hive if we mounted it
        if ($hiveMounted) {
            Start-Sleep -Seconds 1
            reg unload "HKU\$libUserSID" | Out-Null
        }
    }
    catch {
        Write-Host "Error checking Edge homepage: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Main execution
Write-Host "Windows 11 Pro Edge Homepage Setter for LibUser" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "This script sets Edge homepage for LibUser account only" -ForegroundColor Cyan

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

# Define the homepage URL
$homepageURL = "https://www.hitechsupport.com.au"

# Check if LibUser exists
try {
    $libUser = Get-LocalUser -Name "LibUser" -ErrorAction SilentlyContinue
    if (-not $libUser) {
        Write-Host "Error: LibUser account not found. Cannot set homepage." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "LibUser account found. Setting Edge homepage..." -ForegroundColor Green
    }
}
catch {
    Write-Host "Error: Could not check for LibUser account." -ForegroundColor Red
    exit 1
}

try {
    # Show current status
    Get-LibUserEdgeHomepage
    
    Write-Host "`nApplying Edge homepage settings for LibUser..." -ForegroundColor Yellow
    
    # Set homepage
    if (Set-EdgeHomepageForLibUser -HomepageURL $homepageURL) {
        Write-LogEntry "Edge homepage set to $homepageURL for LibUser"
        $success = $true
    } else {
        $success = $false
    }
    
    # Show final status
    Write-Host "`nFinal Status:" -ForegroundColor Cyan
    Get-LibUserEdgeHomepage
    
    if ($success) {
        Write-Host "`nEdge homepage configured successfully for LibUser!" -ForegroundColor Green
        Write-LogEntry "Edge homepage configured successfully for LibUser only"
        Write-Host "LibUser will see the new homepage when starting Edge." -ForegroundColor Yellow
        Write-Host "Other users are not affected by this change." -ForegroundColor Green
    } else {
        Write-Host "`nFailed to configure Edge homepage for LibUser" -ForegroundColor Yellow
    }
    
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $logFile = Join-Path $scriptDir "EdgeHomepageSetter.log"
    Write-Host "`nLog file location: $logFile" -ForegroundColor Cyan
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Usage information
<#
# Simple usage - no parameters needed
.\SetEdgeHomePage.ps1

# What this script does:
# - Sets Edge homepage to https://www.hitechsupport.com.au for LibUser only
# - Configures RestoreOnStartup policy to open specific URLs
# - Uses LibUser-specific registry settings in NTUSER.DAT

# Important notes:
# - Only affects LibUser account, other users are not affected
# - Can be run remotely using System or Administrator account
# - Uses user-specific registry settings in LibUser's profile
# - Changes take effect when LibUser next starts Edge
#>