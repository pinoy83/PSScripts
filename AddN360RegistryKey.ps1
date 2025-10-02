# PowerShell script to add N360 registry key
# Creates the registry key: HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\N360

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

# Define the registry path
$registryPath = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\N360"

try {
    # Check if the key already exists
    if (Test-Path $registryPath) {
        Write-Host "Registry key already exists: $registryPath" -ForegroundColor Yellow
        Write-Host "No action needed." -ForegroundColor Green
    } else {
        # Create the registry key
        Write-Host "Creating registry key: $registryPath" -ForegroundColor Green
        New-Item -Path $registryPath -Force | Out-Null
        
        # Verify the key was created
        if (Test-Path $registryPath) {
            Write-Host "Registry key created successfully!" -ForegroundColor Green
        } else {
            Write-Host "Failed to create registry key." -ForegroundColor Red
            exit 1
        }
    }
    
    Write-Host "`nOperation completed successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Optional: Display the registry key structure
try {
    Write-Host "`nRegistry Key Information:" -ForegroundColor Cyan
    Get-Item $registryPath | Format-List
}
catch {
    Write-Host "Could not display registry key information." -ForegroundColor Yellow
}