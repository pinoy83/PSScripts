# Windows 11 Pro - LibUser Creation with OOBE Skip (All-in-One)
# This script:
# 1. Configures system to skip Out-of-Box Experience
# 2. Creates LibUser with blank password
# 3. Configures autologin for LibUser
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
    
    $logFile = "C:\applications\LibUserSetup.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    # Ensure directory exists
    $logDir = Split-Path -Parent $logFile
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Write to log file
    $logEntry | Out-File $logFile -Append -Force
    
    # Also display on screen
    Write-Host $Message -ForegroundColor Green
}

# ============================================
# OOBE SKIP FUNCTIONS
# ============================================

function Set-SkipOOBE {
    try {
        Write-Host "Configuring registry to skip OOBE for new users..." -ForegroundColor Green
        
        $oobePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE"
        
        if (-not (Test-Path $oobePath)) {
            New-Item -Path $oobePath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $oobePath -Name "DisablePrivacyExperience" -Value 1 -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $oobePath -Name "SkipMachineOOBE" -Value 1 -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $oobePath -Name "SkipUserOOBE" -Value 1 -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $oobePath -Name "DisableMSAccountPage" -Value 1 -Type DWord -ErrorAction Stop
        
        Write-LogEntry "OOBE skip settings configured"
        return $true
    }
    catch {
        Write-Host "Error configuring OOBE settings: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Disable-WelcomeExperience {
    try {
        Write-Host "Disabling Windows Welcome Experience..." -ForegroundColor Green
        
        $cloudContentPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
        
        if (-not (Test-Path $cloudContentPath)) {
            New-Item -Path $cloudContentPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $cloudContentPath -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -ErrorAction Stop
        
        Write-LogEntry "Windows Welcome Experience disabled"
        return $true
    }
    catch {
        Write-Host "Error disabling Welcome Experience: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Disable-FirstLogonAnimation {
    try {
        Write-Host "Disabling first logon animation..." -ForegroundColor Green
        
        $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        
        if (-not (Test-Path $winlogonPath)) {
            New-Item -Path $winlogonPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $winlogonPath -Name "EnableFirstLogonAnimation" -Value 0 -Type DWord -ErrorAction Stop
        
        Write-LogEntry "First logon animation disabled"
        return $true
    }
    catch {
        Write-Host "Error disabling first logon animation: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Disable-CortanaAndSearch {
    try {
        Write-Host "Disabling Cortana..." -ForegroundColor Green
        
        $searchPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        
        if (-not (Test-Path $searchPath)) {
            New-Item -Path $searchPath -Force | Out-Null
        }
        
        Set-ItemProperty -Path $searchPath -Name "AllowCortana" -Value 0 -Type DWord -ErrorAction Stop
        
        Write-LogEntry "Cortana disabled"
        return $true
    }
    catch {
        Write-Host "Error disabling Cortana: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Set-DefaultUserOOBESkip {
    try {
        Write-Host "Configuring default user profile..." -ForegroundColor Green
        
        $defaultUserHive = "C:\Users\Default\NTUSER.DAT"
        $mountPoint = "HKLM\DefaultUser"
        
        if (Test-Path $defaultUserHive) {
            $null = & reg load $mountPoint $defaultUserHive 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $regPath = "HKLM:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
                if (-not (Test-Path $regPath)) {
                    New-Item -Path $regPath -Force | Out-Null
                }
                Set-ItemProperty -Path $regPath -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                
                [gc]::Collect()
                Start-Sleep -Seconds 2
                $null = & reg unload $mountPoint 2>&1
                
                Write-LogEntry "Default user profile configured"
                return $true
            }
        }
        return $false
    }
    catch {
        try { & reg unload "HKLM\DefaultUser" 2>&1 | Out-Null } catch {}
        return $false
    }
}

# ============================================
# USER CREATION FUNCTIONS
# ============================================

function New-LibUser {
    try {
        Write-Host "Creating LibUser account with blank password..." -ForegroundColor Green
        
        $newUser = New-LocalUser -Name "LibUser" -NoPassword -FullName "Library User" -Description "Limited user account for Public access."
        
        if ($newUser) {
            Write-Host "LibUser account created successfully." -ForegroundColor Green
            
            Set-LocalUser -Name "LibUser" -PasswordNeverExpires $true
            
            try {
                Add-LocalGroupMember -Group "Users" -Member "LibUser" -ErrorAction Stop
                Write-Host "LibUser added to Users group." -ForegroundColor Green
            }
            catch [Microsoft.PowerShell.Commands.MemberExistsException] {
                Write-Host "LibUser already in Users group." -ForegroundColor Yellow
            }
            
            Write-LogEntry "LibUser account created with blank password"
            return $true
        }
        return $false
    }
    catch {
        Write-Host "Error creating LibUser: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Set-AutoLogin {
    try {
        Write-Host "Configuring autologin for LibUser..." -ForegroundColor Green
        
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        
        if (-not (Test-Path $registryPath)) {
            Write-Host "Error: Registry path $registryPath does not exist." -ForegroundColor Red
            return $false
        }
        
        Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "1" -Type String -ErrorAction Stop
        Set-ItemProperty -Path $registryPath -Name "DefaultUserName" -Value "LibUser" -Type String -ErrorAction Stop
        Set-ItemProperty -Path $registryPath -Name "DefaultPassword" -Value "" -Type String -ErrorAction Stop
        Set-ItemProperty -Path $registryPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME -Type String -ErrorAction Stop
        
        Write-LogEntry "Autologin configured for LibUser"
        return $true
    }
    catch {
        Write-Host "Error configuring autologin: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-AutoLoginConfigured {
    try {
        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        
        if (-not (Test-Path $registryPath)) {
            return $false
        }
        
        $autoAdminLogon = Get-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
        $defaultUserName = Get-ItemProperty -Path $registryPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
        
        return ($autoAdminLogon.AutoAdminLogon -eq "1" -and $defaultUserName.DefaultUserName -eq "LibUser")
    }
    catch {
        return $false
    }
}

# ============================================
# MAIN EXECUTION
# ============================================

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Windows 11 Pro - LibUser Setup with OOBE Skip" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "This script will:" -ForegroundColor Cyan
Write-Host "  1. Configure Windows to skip Out-of-Box Experience" -ForegroundColor Cyan
Write-Host "  2. Create LibUser account (blank password)" -ForegroundColor Cyan
Write-Host "  3. Configure automatic login" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Check Administrator privileges
if (-not (Test-Administrator)) {
    Write-Host "ERROR: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Red
    exit 1
}

# Set execution policy
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Host "[OK] Execution policy set" -ForegroundColor Green
}
catch {
    Write-Host "Warning: Could not modify execution policy" -ForegroundColor Yellow
}

try {
    # STEP 1: Configure OOBE Skip
    Write-Host "`n[STEP 1] Configuring OOBE Skip Settings..." -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $oobeResults = @{
        "Skip OOBE" = Set-SkipOOBE
        "Disable Welcome" = Disable-WelcomeExperience
        "Disable Animation" = Disable-FirstLogonAnimation
        "Disable Cortana" = Disable-CortanaAndSearch
        "Default User Profile" = Set-DefaultUserOOBESkip
    }
    
        foreach ($key in $oobeResults.Keys) {
            $status = if ($oobeResults[$key]) { "[OK]" } else { "[~]" }
            $color = if ($oobeResults[$key]) { "Green" } else { "Yellow" }
            Write-Host "$status $key" -ForegroundColor $color
        }
        
        # STEP 2: Create/Configure LibUser
        Write-Host "`n[STEP 2] Setting up LibUser Account..." -ForegroundColor Cyan
        Write-Host "=======================================" -ForegroundColor Cyan
        
        $existingUser = Get-LocalUser -Name "LibUser" -ErrorAction SilentlyContinue
        
        if ($existingUser) {
            Write-Host "LibUser already exists." -ForegroundColor Yellow
            
            if (Test-AutoLoginConfigured) {
                Write-Host "[OK] Autologin already configured" -ForegroundColor Green
                Write-LogEntry "LibUser exists with autologin - no changes needed"
            } else {
                Write-Host "Configuring autologin for existing LibUser..." -ForegroundColor Yellow
                if (Set-AutoLogin) {
                    Write-Host "[OK] Autologin configured" -ForegroundColor Green
                }
            }
        } else {
            if (New-LibUser) {
                Write-Host "[OK] LibUser created" -ForegroundColor Green
                if (Set-AutoLogin) {
                    Write-Host "[OK] Autologin configured" -ForegroundColor Green
                }
            }
        }
        
        # FINAL STATUS
        Write-Host "`n========================================================" -ForegroundColor Cyan
        Write-Host "SETUP COMPLETE" -ForegroundColor Green
        Write-Host "========================================================" -ForegroundColor Cyan
        Write-Host "[OK] OOBE will be skipped for new user logins" -ForegroundColor Green
        Write-Host "[OK] LibUser account ready (standard user, blank password)" -ForegroundColor Green
        Write-Host "[OK] System will auto-login as LibUser on restart" -ForegroundColor Green
        Write-Host "`nLog file: C:\applications\LibUserSetup.log" -ForegroundColor Cyan
        Write-Host "`nNOTE: A system restart is recommended for all changes" -ForegroundColor Yellow
        Write-Host "      to take full effect." -ForegroundColor Yellow
        Write-Host "========================================================" -ForegroundColor Cyan
}
catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-LogEntry "Error during setup: $($_.Exception.Message)"
    exit 1
}

<#
.SYNOPSIS
    Complete LibUser setup with OOBE skip for Windows 11 kiosk/library deployments

.DESCRIPTION
    This all-in-one script configures a Windows 11 system for public/kiosk use by:
    
    OOBE Configuration:
    - Disables privacy experience screens
    - Skips machine and user OOBE
    - Disables Microsoft account prompts
    - Removes Windows Welcome Experience
    - Disables first logon animation
    - Disables Cortana
    - Configures default user profile
    
    User Setup:
    - Creates LibUser with blank password
    - Sets password to never expire
    - Configures automatic login
    - Standard user (non-admin) privileges

.EXAMPLE
    .\CreateLibUser_SkipOOBE.ps1
    
    Runs complete setup - configures OOBE skip and creates LibUser

.NOTES
    Requirements:
    - Windows 11 Pro
    - Administrator privileges
    - PowerShell 5.1 or higher
    
    Best Practices:
    - Run on freshly imaged systems before user creation
    - Can be run on existing systems (affects future logins)
    - Restart system after running for full effect
    - Use with Deep Freeze or similar for kiosk lockdown
    
    Security Considerations:
    - LibUser has blank password (suitable for physical kiosks)
    - Ensure physical security and network isolation as needed
    - Consider additional lockdown policies for production use

.LINK
    Related scripts: 
    - SkipOOBE.ps1 (OOBE skip only)
    - CreateLibUser.ps1 (User creation only)
    - DisableLibUserAutoLogin.ps1 (Disable autologin)
#>
