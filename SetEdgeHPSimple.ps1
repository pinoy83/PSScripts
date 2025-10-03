<#
.SYNOPSIS
    Simple Edge Homepage Setter for User Logon
    
.DESCRIPTION
    Sets Microsoft Edge homepage via registry for the current user.
    Designed to run at user logon via Task Scheduler.
    
.NOTES
    Run this at user logon - no elevation required
    Always updates the registry regardless of current values. Upon testing, the policy is being blocked in a workgroup environment..
#>

param(
    [string]$HomepageURL = 'https://www.smh.com.au'
)

# Simple logging function
function Write-SimpleLog {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logLine = "[$timestamp] $Message"
    try {
        $logLine | Out-File -FilePath 'C:\hitech\EdgeHomepage.log' -Encoding UTF8 -Append
    } catch { 
        # Silent fail if can't write log
    }
}

try {
    Write-SimpleLog "Setting Edge homepage to: $HomepageURL"
    
    # Registry paths
    $basePath = 'HKCU:\Software\Policies\Microsoft\Edge'
    $urlsPath = "$basePath\RestoreOnStartupURLs"
    
    # Create registry structure if needed
    if (-not (Test-Path $basePath)) {
        New-Item -Path $basePath -Force | Out-Null
        Write-SimpleLog "Created Edge policies registry path"
    }
    
    if (-not (Test-Path $urlsPath)) {
        New-Item -Path $urlsPath -Force | Out-Null
        Write-SimpleLog "Created RestoreOnStartupURLs registry path"
    }
    
    # Set Edge policies - always update
    Set-ItemProperty -Path $basePath -Name 'RestoreOnStartup' -Value 4 -Type DWord -Force
    Set-ItemProperty -Path $urlsPath -Name '1' -Value $HomepageURL -Type String -Force
    Set-ItemProperty -Path $basePath -Name 'HomepageLocation' -Value $HomepageURL -Type String -Force
    Set-ItemProperty -Path $basePath -Name 'HomepageIsNewTabPage' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $basePath -Name 'ShowHomeButton' -Value 1 -Type DWord -Force
    
    Write-SimpleLog "Edge homepage updated successfully"
}
catch {
    Write-SimpleLog "ERROR: $($_.Exception.Message)"
}