param(
    [string]$HomepageURL = 'https://www.nytimes.com',
    [switch]$CreateTask,
    [string]$TaskUser = $env:USERNAME,
    [switch]$Verbose,
    [switch]$Force  # New parameter to force update even if already configured
)

# Configuration
$LogPath = 'C:\hitech\EdgeHomepage-Startup.log'
$TaskName = 'SetEdgeHomepage'
$ScriptPath = $PSCommandPath

function Write-StartupLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Warn','Error','Success')][string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logLine = "[$timestamp] [$Level] $Message"
    
    try {
        # Ensure log directory exists
        $logDir = Split-Path -Parent $LogPath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        $logLine | Out-File -FilePath $LogPath -Encoding UTF8 -Append -ErrorAction SilentlyContinue
    }
    catch {
        # Silent fail for logging to avoid breaking the main function
    }
    
    if ($Verbose) {
        $color = switch ($Level) {
            'Warn' { 'Yellow' }
            'Error' { 'Red' }
            'Success' { 'Green' }
            default { 'White' }
        }
        Write-Host $logLine -ForegroundColor $color
    }
}

function Set-CurrentUserEdgeHomepage {
    param([Parameter(Mandatory)][string]$Homepage)
    
    try {
        Write-StartupLog -Message "Setting Edge homepage to: $Homepage" -Level Info
        
        # Current user registry paths
        $basePath = 'HKCU:\Software\Policies\Microsoft\Edge'
        $urlsPath = Join-Path $basePath 'RestoreOnStartupURLs'
        
        # Create registry structure if it doesn't exist
        if (-not (Test-Path $basePath)) {
            New-Item -Path $basePath -Force | Out-Null
            Write-StartupLog -Message "Created Edge policies registry path" -Level Info
        }
        
        if (-not (Test-Path $urlsPath)) {
            New-Item -Path $urlsPath -Force | Out-Null
            Write-StartupLog -Message "Created RestoreOnStartupURLs registry path" -Level Info
        }
        
        # Set Edge policies
        Set-ItemProperty -Path $basePath -Name 'RestoreOnStartup' -Value 4 -Type DWord -Force
        Set-ItemProperty -Path $urlsPath -Name '1' -Value $Homepage -Type String -Force
        Set-ItemProperty -Path $basePath -Name 'HomepageLocation' -Value $Homepage -Type String -Force
        Set-ItemProperty -Path $basePath -Name 'HomepageIsNewTabPage' -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $basePath -Name 'ShowHomeButton' -Value 1 -Type DWord -Force
        
        Write-StartupLog -Message "Edge homepage policies applied successfully" -Level Success
        return $true
    }
    catch {
        Write-StartupLog -Message "Failed to set Edge homepage: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Test-EdgeHomepageStatus {
    param([Parameter(Mandatory)][string]$ExpectedURL)
    
    try {
        $basePath = 'HKCU:\Software\Policies\Microsoft\Edge'
        $urlsPath = Join-Path $basePath 'RestoreOnStartupURLs'
        
        if (-not (Test-Path $basePath)) {
            Write-StartupLog -Message "Registry path does not exist: $basePath" -Level Info
            return $false
        }
        
        $restoreMode = Get-ItemProperty -Path $basePath -Name 'RestoreOnStartup' -ErrorAction SilentlyContinue
        $homepageURL = Get-ItemProperty -Path $urlsPath -Name '1' -ErrorAction SilentlyContinue
        
        # Enhanced logging for debugging
        $currentRestoreMode = if ($restoreMode) { $restoreMode.RestoreOnStartup } else { "Not Set" }
        $currentURL = if ($homepageURL) { $homepageURL.'1' } else { "Not Set" }
        
        Write-StartupLog -Message "Current RestoreOnStartup: '$currentRestoreMode' (Expected: 4)" -Level Info
        Write-StartupLog -Message "Current StartupURL: '$currentURL' (Expected: '$ExpectedURL')" -Level Info
        
        $isConfigured = ($restoreMode -and $restoreMode.RestoreOnStartup -eq 4) -and 
                       ($homepageURL -and $homepageURL.'1' -eq $ExpectedURL)
        
        Write-StartupLog -Message "Configuration match result: $isConfigured" -Level Info
        
        return $isConfigured
    }
    catch {
        Write-StartupLog -Message "Error checking homepage status: $($_.Exception.Message)" -Level Warn
        return $false
    }
}

function New-EdgeHomepageTask {
    param(
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][string]$ScriptPath
    )
    
    try {
        Write-StartupLog -Message "Creating scheduled task: $TaskName" -Level Info
        
        # Build schtasks command
        $taskCmd = "powershell.exe"
        $taskArgs = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""
        
        # Create the task
        $schtasksArgs = @(
            '/create'
            '/tn', $TaskName
            '/tr', "`"$taskCmd`" $taskArgs"
            '/sc', 'onlogon'
            '/ru', $Username
            '/rl', 'limited'
            '/f'
        )
        
        $result = & schtasks.exe @schtasksArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-StartupLog -Message "Task created successfully for user: $Username" -Level Success
            Write-StartupLog -Message "Task will run: $taskCmd $taskArgs" -Level Info
            return $true
        }
        else {
            Write-StartupLog -Message "Failed to create task. Exit code: $LASTEXITCODE" -Level Error
            Write-StartupLog -Message "Output: $($result -join ' ')" -Level Error
            return $false
        }
    }
    catch {
        Write-StartupLog -Message "Error creating scheduled task: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Remove-EdgeHomepageTask {
    try {
        Write-StartupLog -Message "Removing scheduled task: $TaskName" -Level Info
        
        $result = & schtasks.exe /delete /tn $TaskName /f
        
        if ($LASTEXITCODE -eq 0) {
            Write-StartupLog -Message "Task removed successfully" -Level Success
            return $true
        }
        else {
            Write-StartupLog -Message "Failed to remove task or task not found" -Level Warn
            return $false
        }
    }
    catch {
        Write-StartupLog -Message "Error removing scheduled task: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Main execution
Write-StartupLog -Message "=== Edge Homepage Startup Script Started ===" -Level Info
Write-StartupLog -Message "User: $env:USERNAME, Computer: $env:COMPUTERNAME" -Level Info
Write-StartupLog -Message "Target Homepage: $HomepageURL" -Level Info
Write-StartupLog -Message "Force Update: $Force" -Level Info

if ($CreateTask) {
    Write-StartupLog -Message "Task creation mode enabled" -Level Info
    
    # Verify we're running as administrator for task creation
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-StartupLog -Message "Task creation requires administrator privileges" -Level Error
        Write-Host "ERROR: Must run as Administrator to create scheduled tasks" -ForegroundColor Red
        Write-StartupLog -Message "Script exiting with code 1" -Level Error
        exit 1
    }
    
    if (New-EdgeHomepageTask -Username $TaskUser -ScriptPath $ScriptPath) {
        Write-Host "SUCCESS: Scheduled task '$TaskName' created for user '$TaskUser'" -ForegroundColor Green
        Write-Host "Task will run at login and set Edge homepage to: $HomepageURL" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "To test manually:" -ForegroundColor Yellow
        Write-Host "schtasks /run /tn `"$TaskName`"" -ForegroundColor Gray
        Write-Host ""
        Write-Host "To remove task:" -ForegroundColor Yellow  
        Write-Host "schtasks /delete /tn `"$TaskName`" /f" -ForegroundColor Gray
        Write-StartupLog -Message "Script completed successfully with code 0" -Level Success
    }
    else {
        Write-Host "FAILED: Could not create scheduled task" -ForegroundColor Red
        Write-StartupLog -Message "Script exiting with code 1" -Level Error
        exit 1
    }
}
else {
    # Normal execution - set homepage for current user
    Write-StartupLog -Message "Checking current homepage configuration..." -Level Info
    
    $isCurrentlyConfigured = Test-EdgeHomepageStatus -ExpectedURL $HomepageURL
    
    if ($isCurrentlyConfigured -and -not $Force) {
        Write-StartupLog -Message "Homepage already configured correctly, no changes needed" -Level Success
        Write-StartupLog -Message "Script completed successfully with code 0" -Level Success
    }
    elseif ($Force) {
        Write-StartupLog -Message "Force update requested, applying configuration regardless of current state" -Level Info
        
        if (Set-CurrentUserEdgeHomepage -Homepage $HomepageURL) {
            # Verify the change
            Start-Sleep -Milliseconds 500
            if (Test-EdgeHomepageStatus -ExpectedURL $HomepageURL) {
                Write-StartupLog -Message "Homepage configured and verified successfully (forced)" -Level Success
                Write-StartupLog -Message "Script completed successfully with code 0" -Level Success
            }
            else {
                Write-StartupLog -Message "Homepage set but verification failed (forced)" -Level Warn
                Write-StartupLog -Message "Script completed with warning, exit code 0" -Level Warn
            }
        }
        else {
            Write-StartupLog -Message "Failed to configure homepage (forced)" -Level Error
            Write-StartupLog -Message "Script exiting with code 1" -Level Error
            exit 1
        }
    }
    else {
        Write-StartupLog -Message "Homepage needs configuration, applying changes..." -Level Info
        
        if (Set-CurrentUserEdgeHomepage -Homepage $HomepageURL) {
            # Verify the change
            Start-Sleep -Milliseconds 500
            if (Test-EdgeHomepageStatus -ExpectedURL $HomepageURL) {
                Write-StartupLog -Message "Homepage configured and verified successfully" -Level Success
                Write-StartupLog -Message "Script completed successfully with code 0" -Level Success
            }
            else {
                Write-StartupLog -Message "Homepage set but verification failed" -Level Warn
                Write-StartupLog -Message "Script completed with warning, exit code 0" -Level Warn
            }
        }
        else {
            Write-StartupLog -Message "Failed to configure homepage" -Level Error
            Write-StartupLog -Message "Script exiting with code 1" -Level Error
            exit 1
        }
    }
}

Write-StartupLog -Message "=== Edge Homepage Startup Script Completed ===" -Level Info