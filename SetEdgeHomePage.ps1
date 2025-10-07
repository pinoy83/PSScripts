# Refactored: Windows 11 Edge Homepage Setter for specific local user (LibUser)
# Purpose:
#   Sets Microsoft Edge startup behavior and homepage-related policies ONLY for the target user account.
#   - Opens specified homepage URL at startup (RestoreOnStartup = 4 + URL list)
#   - Sets Homepage button + Homepage location policies
#   - Does NOT affect other users
#
# Requirements:
#   - Run as Administrator (to load target user's NTUSER.DAT hive if not logged on)
#   - PowerShell 5.1+ / Windows 10/11 with Edge Chromium
#   - Target user must exist as a local user account
#   - PC must be domain-joined/managed (via Intune or WFUB not workgroup) 
#
# Policies Applied Under User Hive (HKU:<SID>\Software\Policies\Microsoft\Edge):
#   RestoreOnStartup            (DWORD) 4  -> Open a list of URLs
#   RestoreOnStartupURLs\1      (REG_SZ)   -> Homepage URL
#   HomepageLocation             (REG_SZ)   -> Homepage URL (optional but useful if Home button used)
#   HomepageIsNewTabPage         (DWORD) 0  -> Ensure homepage isn't overridden by new tab
#   ShowHomeButton               (DWORD) 1  -> Expose Home button (optional UX improvement)
#
# Exit Codes:
#   0 = Success
#   1 = Not Administrator
#   2 = Target user not found
#   3 = Failed to load user hive
#   4 = Failed registry write or verification mismatch
#   5 = Unexpected error

param(
    [string]$TargetUser = 'LibUser',
    [string]$HomepageURL = 'https://www.nytimes.com'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Configuration
$LogFile = Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath 'EdgeHomepageSetter.log'
#endregion Configuration

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Warn','Error','Success')][string]$Level = 'Info'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $prefix = '[INFO ]'
    $color = 'Gray'
    switch ($Level) {
        'Warn'    { $prefix='[WARN ]'; $color='Yellow' }
        'Error'   { $prefix='[ERROR]'; $color='Red' }
        'Success' { $prefix='[ OK  ]'; $color='Green' }
    }
    $line = "[$timestamp] $prefix $Message"
    $line | Out-File -FilePath $LogFile -Encoding UTF8 -Append
    Write-Host $Message -ForegroundColor $color
}

function Ensure-HKURoot {
    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        try {
            New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -Scope Script | Out-Null
            Write-Log -Message 'Created HKU: PSDrive' -Level Info
        }
        catch {
            Write-Log -Level Error -Message "Failed to create HKU PSDrive: $($_.Exception.Message)"
            throw
        }
    }
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-LocalUserSidValue {
    param([Parameter(Mandatory)][string]$UserName)
    try {
        $user = Get-LocalUser -Name $UserName -ErrorAction Stop
        return $user.SID.Value
    }
    catch {
        return $null
    }
}

function Mount-UserHiveIfNeeded {
    <#
        .SYNOPSIS
            Ensures HKU:\<SID> is available; loads NTUSER.DAT if needed.
        .OUTPUTS
            [pscustomobject] @{ Sid=<sid>; Mounted=$true/$false; HiveLoaded=$true if we loaded } or $null on failure
    #>
    param(
        [Parameter(Mandatory)][string]$Sid,
        [Parameter(Mandatory)][string]$UserName,
        [int]$RetryCount = 2,
        [int]$RetryDelayMs = 700
    )
    Ensure-HKURoot
    $already = Test-Path "HKU:\$Sid"
    if ($already) {
        return [pscustomobject]@{ Sid=$Sid; Mounted=$true; HiveLoaded=$false }
    }
    $profilePath = $null
    for ($i=0; $i -le $RetryCount -and -not $profilePath; $i++) {
        $profile = Get-WmiObject -Class Win32_UserProfile -Filter "SID='$Sid'" -ErrorAction SilentlyContinue
        if ($profile -and $profile.LocalPath -and (Test-Path $profile.LocalPath)) {
            $profilePath = $profile.LocalPath
            break
        }
        if ($i -lt $RetryCount) { Start-Sleep -Milliseconds $RetryDelayMs }
    }
    if (-not $profilePath) {
        # Fallback: assume standard user profile path (may fail if roaming / renamed)
        $assumed = Join-Path $env:SystemDrive (Join-Path 'Users' $UserName)
        if (Test-Path $assumed) {
            Write-Log -Level Warn -Message "Falling back to assumed profile path: $assumed"
            $profilePath = $assumed
        }
    }
    if (-not $profilePath) {
        Write-Log -Level Error -Message "Failed to resolve profile path for SID $Sid"
        return $null
    }
    $ntUserDat = Join-Path $profilePath 'NTUSER.DAT'
    if (-not (Test-Path $ntUserDat)) {
        Write-Log -Level Error -Message "NTUSER.DAT not found at $ntUserDat"
        return $null
    }
    try {
        & reg.exe load "HKU\$Sid" "$ntUserDat" | Out-Null
        Write-Log -Level Info -Message "Loaded user hive for SID $Sid"
        return [pscustomobject]@{ Sid=$Sid; Mounted=$true; HiveLoaded=$true }
    }
    catch {
        Write-Log -Level Error -Message "Failed to load user hive: $($_.Exception.Message)"
        return $null
    }
}

function Dismount-UserHiveIfLoaded {
    param(
        [Parameter(Mandatory)][pscustomobject]$HiveInfo
    )
    if ($HiveInfo.HiveLoaded -and (Test-Path "HKU:\$($HiveInfo.Sid)")) {
        try {
            Start-Sleep -Milliseconds 500
            & reg.exe unload "HKU\$($HiveInfo.Sid)" | Out-Null
            Write-Log -Level Info -Message "Unloaded user hive for SID $($HiveInfo.Sid)"
        }
        catch {
            Write-Log -Level Warn -Message "Could not unload user hive (in use?): $($_.Exception.Message)"
        }
    }
}

function Ensure-RegistryPath {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
}

function Set-EdgeHomepageForUser {
    <#
        .RETURNS $true on success, $false on failure
    #>
    param(
        [Parameter(Mandatory)][string]$Sid,
        [Parameter(Mandatory)][string]$Homepage
    )
    try {
        Ensure-HKURoot
        $base = "HKU:\$Sid\Software\Policies\Microsoft\Edge"
        $urls = Join-Path $base 'RestoreOnStartupURLs'
        Ensure-RegistryPath -Path $base
        Ensure-RegistryPath -Path $urls

        New-ItemProperty -Path $base -Name 'RestoreOnStartup' -PropertyType DWord -Value 4 -Force | Out-Null
        New-ItemProperty -Path $urls -Name '1' -PropertyType String -Value $Homepage -Force | Out-Null

        New-ItemProperty -Path $base -Name 'HomepageLocation' -PropertyType String -Value $Homepage -Force | Out-Null
        New-ItemProperty -Path $base -Name 'HomepageIsNewTabPage' -PropertyType DWord -Value 0 -Force | Out-Null
        New-ItemProperty -Path $base -Name 'ShowHomeButton' -PropertyType DWord -Value 1 -Force | Out-Null

        Write-Log -Level Success -Message "Policies applied for SID $Sid"
        return $true
    }
    catch {
        Write-Log -Level Error -Message "Failed writing Edge policies: $($_.Exception.Message)"
        return $false
    }
}

function Get-EdgeHomepageStatusForUser {
    param([Parameter(Mandatory)][string]$Sid)
    $base = "HKU:\$Sid\Software\Policies\Microsoft\Edge"
    $urls = "$base\RestoreOnStartupURLs"
    $result = [ordered]@{ Sid=$Sid; Exists=$false; StartupMode=$null; URL=$null; HomepageLocation=$null }
    if (-not (Test-Path $base)) { return [pscustomobject]$result }
    $result.Exists = $true
    $props = Get-ItemProperty -Path $base -ErrorAction SilentlyContinue
    if ($props) { $result.StartupMode = $props.RestoreOnStartup; $result.HomepageLocation = $props.HomepageLocation }
    if (Test-Path $urls) {
        $u1 = (Get-ItemProperty -Path $urls -Name '1' -ErrorAction SilentlyContinue)
        if ($u1) { $result.URL = $u1.'1' }
    }
    return [pscustomobject]$result
}

Write-Host 'Edge Homepage Setter (User-Specific Policy)' -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan
Write-Host "Target User : $TargetUser" -ForegroundColor Cyan
Write-Host "Homepage    : $HomepageURL" -ForegroundColor Cyan

if (-not (Test-Administrator)) {
    Write-Log -Level Error -Message 'Must be run elevated (Administrator).'
    Write-Host 'Exit Code : 1' -ForegroundColor Cyan
    exit 1
}

Write-Log -Message 'Starting operation...'

# Ensure HKU provider is available early
Ensure-HKURoot

$sid = Get-LocalUserSidValue -UserName $TargetUser
if (-not $sid) {
    Write-Log -Level Error -Message "User '$TargetUser' not found. Aborting."
    Write-Host 'Exit Code : 2' -ForegroundColor Cyan
    exit 2
}
Write-Log -Message "Resolved SID: $sid"

$hiveInfo = Mount-UserHiveIfNeeded -Sid $sid -UserName $TargetUser
if (-not $hiveInfo) {
    Write-Log -Level Error -Message 'Unable to mount or access user hive.'
    Write-Host 'Exit Code : 3' -ForegroundColor Cyan
    exit 3
}

try {
    $statusBefore = Get-EdgeHomepageStatusForUser -Sid $sid
    Write-Log -Message ("Before: StartupMode={0} URL={1}" -f $($statusBefore.StartupMode), $($statusBefore.URL))

    if (-not (Set-EdgeHomepageForUser -Sid $sid -Homepage $HomepageURL)) {
        Write-Host 'Exit Code : 4 (Failed applying policies)' -ForegroundColor Yellow
        exit 4
    }

    $statusAfter = Get-EdgeHomepageStatusForUser -Sid $sid
    Write-Host ''
    Write-Host 'Verification:' -ForegroundColor Cyan
    Write-Host ("  Startup Mode : {0}" -f $statusAfter.StartupMode)
    Write-Host ("  Startup URL  : {0}" -f $statusAfter.URL)
    Write-Host ("  Homepage     : {0}" -f $statusAfter.HomepageLocation)

    if ($statusAfter.StartupMode -eq 4 -and $statusAfter.URL -eq $HomepageURL) {
        Write-Log -Level Success -Message 'Homepage policy applied successfully.'
        Write-Host 'Exit Code : 0' -ForegroundColor Cyan
        exit 0
    } else {
        Write-Log -Level Warn -Message 'Policies applied but verification did not match expected values.'
        Write-Host 'Exit Code : 4 (Verification mismatch)' -ForegroundColor Yellow
        exit 4
    }
}
catch {
    Write-Log -Level Error -Message "Unexpected failure: $($_.Exception.Message)"
    Write-Host 'Exit Code : 5' -ForegroundColor Cyan
    exit 5
}
finally {
    Dismount-UserHiveIfLoaded -HiveInfo $hiveInfo
    Write-Log -Message 'Completed.'
}

# End of script