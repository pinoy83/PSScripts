# Copy Microsoft Edge Shortcut Script
# This script copies 'Microsoft Edge.lnk' to Start Menu and Public Desktop
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
    
    $logFile = "C:\applications\CopyEdgeShortcut.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    # Write to log file
    $logEntry | Out-File $logFile -Append -Force
    
    # Also display on screen
    Write-Host $Message -ForegroundColor Green
}

Write-Host "Copy Microsoft Edge Shortcut Script" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

# Check if running as Administrator
if (-not (Test-Administrator)) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Define paths
$sourceFile = "C:\Applications\Microsoft Edge.lnk"
$destination1 = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$destination2 = "C:\Users\Public\Desktop"

$successCount = 0
$totalCopies = 2

try {
    # Check if source file exists
    if (-not (Test-Path $sourceFile)) {
        Write-Host "Error: Source file not found: $sourceFile" -ForegroundColor Red
        Write-LogEntry "Error: Source file not found: $sourceFile"
        exit 1
    }
    
    Write-Host "Source file found: $sourceFile" -ForegroundColor Green
    Write-LogEntry "Source file found: $sourceFile"
    
    # Copy to Start Menu Programs folder
    Write-Host "`nCopying to Start Menu..." -ForegroundColor Yellow
    try {
        Copy-Item -Path $sourceFile -Destination $destination1 -Force -ErrorAction Stop
        Write-Host "Successfully copied to: $destination1" -ForegroundColor Green
        Write-LogEntry "Copied to Start Menu: $destination1"
        $successCount++
    }
    catch {
        Write-Host "Failed to copy to Start Menu: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogEntry "Error copying to Start Menu: $($_.Exception.Message)"
    }
    
    # Copy to Public Desktop
    Write-Host "`nCopying to Public Desktop..." -ForegroundColor Yellow
    try {
        Copy-Item -Path $sourceFile -Destination $destination2 -Force -ErrorAction Stop
        Write-Host "Successfully copied to: $destination2" -ForegroundColor Green
        Write-LogEntry "Copied to Public Desktop: $destination2"
        $successCount++
    }
    catch {
        Write-Host "Failed to copy to Public Desktop: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogEntry "Error copying to Public Desktop: $($_.Exception.Message)"
    }
    
    # Summary
    Write-Host "`n===================================" -ForegroundColor Cyan
    if ($successCount -eq $totalCopies) {
        Write-Host "Operation completed successfully!" -ForegroundColor Green
        Write-Host "Shortcut copied to all locations: $successCount/$totalCopies" -ForegroundColor Green
        Write-LogEntry "Operation completed successfully - $successCount/$totalCopies copies made"
    }
    elseif ($successCount -gt 0) {
        Write-Host "Operation completed with warnings." -ForegroundColor Yellow
        Write-Host "Shortcuts copied: $successCount/$totalCopies" -ForegroundColor Yellow
        Write-LogEntry "Operation completed with warnings - $successCount/$totalCopies copies made"
        exit 1
    }
    else {
        Write-Host "Operation failed - no shortcuts copied." -ForegroundColor Red
        Write-LogEntry "Operation failed - no shortcuts copied"
        exit 1
    }
    
    Write-Host "`nLog file: C:\applications\CopyEdgeShortcut.log" -ForegroundColor Cyan
}
catch {
    Write-Host "Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    Write-LogEntry "Unexpected error: $($_.Exception.Message)"
    exit 1
}

# Example usage:
<#
# Copy Microsoft Edge shortcut to Start Menu and Public Desktop
.\CopyEdgeShortcut.ps1

# The script will:
# 1. Check if running as Administrator
# 2. Verify source file exists: C:\Applications\Microsoft Edge.lnk
# 3. Copy to: C:\ProgramData\Microsoft\Windows\Start Menu\Programs
# 4. Copy to: C:\Users\Public\Desktop
# 5. Log all actions to: C:\applications\CopyEdgeShortcut.log

# Result:
# - The shortcut will appear in the Start Menu for all users
# - The shortcut will appear on the Public Desktop (visible to all users)

# To verify:
# - Check Start Menu: Press Win key and look for Microsoft Edge
# - Check Desktop: Look for Microsoft Edge shortcut on desktop
#>