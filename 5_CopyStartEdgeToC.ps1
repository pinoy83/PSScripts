# Copy Microsoft Edge Shortcut, Start Menu Layout, and Terms of Use Files
# This script copies 'Microsoft Edge.lnk' to Start Menu and Public Desktop
# Also copies start2.bin to LibUser's Start Menu layout folder
# And copies Terms of Use HTML and logo to LibUser's Desktop
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

Write-Host "Copy Microsoft Edge Shortcut, Start Menu Layout, and Terms of Use Files" -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan

# Check if running as Administrator
if (-not (Test-Administrator)) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define paths for Edge shortcut
$edgeSourceFile = "C:\Applications\Microsoft Edge.lnk"
$edgeDestination1 = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$edgeDestination2 = "C:\Users\Public\Desktop"

# Define paths for start2.bin
$start2SourceFile = Join-Path $scriptDir "start2.bin"
$start2Destination = "C:\Users\LibUser\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
$start2DestinationFolder = Split-Path -Parent $start2Destination
$start2Backup = "C:\Users\LibUser\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin.old"

# Define paths for Terms of Use files
$htmlSourceFile = Join-Path $scriptDir "Conditions_of_Use_for_Public_Access_PCs.html"
$logoSourceFile = Join-Path $scriptDir "logo.png"
$libUserDesktop = "C:\Users\LibUser\Desktop"

$successCount = 0
$totalCopies = 5

try {
    # ===== COPY EDGE SHORTCUT =====
    
    # Check if Edge shortcut source file exists
    if (-not (Test-Path $edgeSourceFile)) {
        Write-Host "Error: Edge shortcut not found: $edgeSourceFile" -ForegroundColor Red
        Write-LogEntry "Error: Edge shortcut not found: $edgeSourceFile"
        exit 1
    }
    
    Write-Host "Edge shortcut found: $edgeSourceFile" -ForegroundColor Green
    Write-LogEntry "Edge shortcut found: $edgeSourceFile"
    
    # Copy to Start Menu Programs folder
    Write-Host "`nCopying Edge shortcut to Start Menu..." -ForegroundColor Yellow
    try {
        Copy-Item -Path $edgeSourceFile -Destination $edgeDestination1 -Force -ErrorAction Stop
        Write-Host "Successfully copied to: $edgeDestination1" -ForegroundColor Green
        Write-LogEntry "Copied to Start Menu: $edgeDestination1"
        $successCount++
    }
    catch {
        Write-Host "Failed to copy to Start Menu: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogEntry "Error copying to Start Menu: $($_.Exception.Message)"
    }
    
    # Copy to Public Desktop
    Write-Host "`nCopying Edge shortcut to Public Desktop..." -ForegroundColor Yellow
    try {
        Copy-Item -Path $edgeSourceFile -Destination $edgeDestination2 -Force -ErrorAction Stop
        Write-Host "Successfully copied to: $edgeDestination2" -ForegroundColor Green
        Write-LogEntry "Copied to Public Desktop: $edgeDestination2"
        $successCount++
    }
    catch {
        Write-Host "Failed to copy to Public Desktop: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogEntry "Error copying to Public Desktop: $($_.Exception.Message)"
    }
    
    # ===== COPY START2.BIN =====
    
    Write-Host "`n--- Start Menu Layout Configuration ---" -ForegroundColor Cyan
    
    # Check if start2.bin source file exists
    if (-not (Test-Path $start2SourceFile)) {
        Write-Host "Warning: start2.bin not found: $start2SourceFile" -ForegroundColor Yellow
        Write-Host "Skipping Start Menu layout copy." -ForegroundColor Yellow
        Write-LogEntry "Warning: start2.bin not found - skipping copy"
    }
    else {
        Write-Host "start2.bin found: $start2SourceFile" -ForegroundColor Green
        Write-LogEntry "start2.bin found: $start2SourceFile"
        
        # Create destination folder if it doesn't exist
        if (-not (Test-Path $start2DestinationFolder)) {
            Write-Host "Creating destination folder: $start2DestinationFolder" -ForegroundColor Yellow
            try {
                New-Item -Path $start2DestinationFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Host "Folder created successfully." -ForegroundColor Green
                Write-LogEntry "Created folder: $start2DestinationFolder"
            }
            catch {
                Write-Host "Failed to create folder: $($_.Exception.Message)" -ForegroundColor Red
                Write-LogEntry "Error creating folder: $($_.Exception.Message)"
            }
        }
        
        # Check if destination start2.bin already exists and backup if needed
        if (Test-Path $start2Destination) {
            Write-Host "`nExisting start2.bin found. Creating backup..." -ForegroundColor Yellow
            try {
                # Remove old backup if it exists
                if (Test-Path $start2Backup) {
                    Remove-Item -Path $start2Backup -Force -ErrorAction Stop
                    Write-Host "Removed old backup: $start2Backup" -ForegroundColor Cyan
                }
                
                # Rename current file to .old
                Rename-Item -Path $start2Destination -NewName "start2.bin.old" -Force -ErrorAction Stop
                Write-Host "Backed up existing file to: start2.bin.old" -ForegroundColor Green
                Write-LogEntry "Backed up existing start2.bin to start2.bin.old"
            }
            catch {
                Write-Host "Warning: Could not backup existing file: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-LogEntry "Warning: Could not backup start2.bin - $($_.Exception.Message)"
            }
        }
        
        # Copy start2.bin to destination
        Write-Host "`nCopying start2.bin to LibUser Start Menu folder..." -ForegroundColor Yellow
        try {
            Copy-Item -Path $start2SourceFile -Destination $start2Destination -Force -ErrorAction Stop
            Write-Host "Successfully copied to: $start2Destination" -ForegroundColor Green
            Write-LogEntry "Copied start2.bin to: $start2Destination"
            $successCount++
        }
        catch {
            Write-Host "Failed to copy start2.bin: $($_.Exception.Message)" -ForegroundColor Red
            Write-LogEntry "Error copying start2.bin: $($_.Exception.Message)"
        }
    }
    
    # ===== COPY TERMS OF USE FILES =====
    
    Write-Host "`n--- Terms of Use Files ---" -ForegroundColor Cyan
    
    # Create LibUser Desktop folder if it doesn't exist
    if (-not (Test-Path $libUserDesktop)) {
        Write-Host "Creating LibUser Desktop folder: $libUserDesktop" -ForegroundColor Yellow
        try {
            New-Item -Path $libUserDesktop -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Host "Desktop folder created successfully." -ForegroundColor Green
            Write-LogEntry "Created LibUser Desktop folder: $libUserDesktop"
        }
        catch {
            Write-Host "Failed to create Desktop folder: $($_.Exception.Message)" -ForegroundColor Red
            Write-LogEntry "Error creating Desktop folder: $($_.Exception.Message)"
        }
    }
    
    # Copy HTML file
    if (-not (Test-Path $htmlSourceFile)) {
        Write-Host "Warning: HTML file not found: $htmlSourceFile" -ForegroundColor Yellow
        Write-Host "Skipping Terms of Use HTML copy." -ForegroundColor Yellow
        Write-LogEntry "Warning: HTML file not found - skipping copy"
    }
    else {
        Write-Host "`nCopying Terms of Use HTML to LibUser Desktop..." -ForegroundColor Yellow
        try {
            $htmlDestination = Join-Path $libUserDesktop "Conditions_of_Use_for_Public_Access_PCs.html"
            Copy-Item -Path $htmlSourceFile -Destination $htmlDestination -Force -ErrorAction Stop
            Write-Host "Successfully copied to: $htmlDestination" -ForegroundColor Green
            Write-LogEntry "Copied HTML to: $htmlDestination"
            $successCount++
        }
        catch {
            Write-Host "Failed to copy HTML file: $($_.Exception.Message)" -ForegroundColor Red
            Write-LogEntry "Error copying HTML file: $($_.Exception.Message)"
        }
    }
    
    # Copy logo.png file
    if (-not (Test-Path $logoSourceFile)) {
        Write-Host "Warning: Logo file not found: $logoSourceFile" -ForegroundColor Yellow
        Write-Host "Skipping logo copy." -ForegroundColor Yellow
        Write-LogEntry "Warning: Logo file not found - skipping copy"
    }
    else {
        Write-Host "`nCopying logo.png to LibUser Desktop..." -ForegroundColor Yellow
        try {
            $logoDestination = Join-Path $libUserDesktop "logo.png"
            Copy-Item -Path $logoSourceFile -Destination $logoDestination -Force -ErrorAction Stop
            Write-Host "Successfully copied to: $logoDestination" -ForegroundColor Green
            Write-LogEntry "Copied logo to: $logoDestination"
            $successCount++
        }
        catch {
            Write-Host "Failed to copy logo file: $($_.Exception.Message)" -ForegroundColor Red
            Write-LogEntry "Error copying logo file: $($_.Exception.Message)"
        }
    }
    
    # ===== SUMMARY =====
    
    Write-Host "`n========================================================================" -ForegroundColor Cyan
    if ($successCount -eq $totalCopies) {
        Write-Host "Operation completed successfully!" -ForegroundColor Green
        Write-Host "All files copied: $successCount/$totalCopies" -ForegroundColor Green
        Write-LogEntry "Operation completed successfully - $successCount/$totalCopies copies made"
    }
    elseif ($successCount -gt 0) {
        Write-Host "Operation completed with warnings." -ForegroundColor Yellow
        Write-Host "Files copied: $successCount/$totalCopies" -ForegroundColor Yellow
        Write-LogEntry "Operation completed with warnings - $successCount/$totalCopies copies made"
    }
    else {
        Write-Host "Operation failed - no files copied." -ForegroundColor Red
        Write-LogEntry "Operation failed - no files copied"
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
# Copy Microsoft Edge shortcut, Start Menu layout, and Terms of Use files
.\5_CopyEdgeLnkAndStart2Bin.ps1

# The script will:
# 1. Check if running as Administrator
# 2. Copy Microsoft Edge.lnk to:
#    - C:\ProgramData\Microsoft\Windows\Start Menu\Programs
#    - C:\Users\Public\Desktop
# 3. Copy start2.bin (from script folder) to:
#    - C:\Users\LibUser\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\
#    - If start2.bin exists at destination, rename it to start2.bin.old
# 4. Copy Conditions_of_Use_for_Public_Access_PCs.html to:
#    - C:\Users\LibUser\Desktop
# 5. Copy logo.png to:
#    - C:\Users\LibUser\Desktop
# 6. Log all actions to: C:\applications\CopyEdgeShortcut.log

# Prerequisites:
# - C:\Applications\Microsoft Edge.lnk must exist
# - start2.bin must be in the same folder as the script
# - Conditions_of_Use_for_Public_Access_PCs.html must be in the same folder as the script
# - logo.png must be in the same folder as the script
# - LibUser account must exist

# Result:
# - Edge shortcut in Start Menu and Public Desktop
# - Custom Start Menu layout for LibUser
# - Terms of Use HTML and logo on LibUser's Desktop
# - Previous Start Menu layout backed up as start2.bin.old
#>