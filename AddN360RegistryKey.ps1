# PowerShell script to add N360 registry key
# Creates registry keys for both 32-bit and 64-bit registry paths
# 32-bit OS: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\N360
# 64-bit OS: HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\N360

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Host "N360 Registry Key Creation Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

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

# Define the registry paths
$registryPath64 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\N360"
$registryPath32 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\N360"

$successCount = 0
$totalKeys = 2

try {
    # Create the 64-bit registry key (WOW6432Node)
    Write-Host "`nCreating registry key: $registryPath64" -ForegroundColor Yellow
    if (Test-Path $registryPath64) {
        Write-Host "Registry key already exists: $registryPath64" -ForegroundColor Cyan
        $successCount++
    } else {
        New-Item -Path $registryPath64 -Force | Out-Null
        
        if (Test-Path $registryPath64) {
            Write-Host "Registry key created successfully!" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "Failed to create registry key." -ForegroundColor Red
        }
    }
    
    # Create the 32-bit registry key
    Write-Host "`nCreating registry key: $registryPath32" -ForegroundColor Yellow
    if (Test-Path $registryPath32) {
        Write-Host "Registry key already exists: $registryPath32" -ForegroundColor Cyan
        $successCount++
    } else {
        New-Item -Path $registryPath32 -Force | Out-Null
        
        if (Test-Path $registryPath32) {
            Write-Host "Registry key created successfully!" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "Failed to create registry key." -ForegroundColor Red
        }
    }
    
    # Summary
    Write-Host "`n=================================" -ForegroundColor Cyan
    if ($successCount -eq $totalKeys) {
        Write-Host "Operation completed successfully." -ForegroundColor Green
        Write-Host "All registry keys created/verified: $successCount/$totalKeys" -ForegroundColor Green
    } else {
        Write-Host "Operation completed with warnings." -ForegroundColor Yellow
        Write-Host "Registry keys created/verified: $successCount/$totalKeys" -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Optional: Display the registry key structure
try {
    Write-Host "`nRegistry Keys Information:" -ForegroundColor Cyan
    
    if (Test-Path $registryPath64) {
        Write-Host "`n64-bit path (WOW6432Node):" -ForegroundColor Yellow
        Get-Item $registryPath64 | Format-List
    }
    
    if (Test-Path $registryPath32) {
        Write-Host "32-bit path:" -ForegroundColor Yellow
        Get-Item $registryPath32 | Format-List
    }
}
catch {
    Write-Host "Could not display registry key information." -ForegroundColor Yellow
}