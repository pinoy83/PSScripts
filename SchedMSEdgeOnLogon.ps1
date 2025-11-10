# Create MSEdge On Logon Scheduled Task from XML
# This script imports a scheduled task from an XML file
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
    
    $logFile = "C:\applications\CreateMSEdgeTask.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    # Write to log file
    $logEntry | Out-File $logFile -Append -Force
    
    # Also display on screen
    Write-Host $Message -ForegroundColor Green
}

# Main execution
Write-Host "Create MSEdge On Logon Scheduled Task from XML" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# Check if running as Administrator
if (-not (Test-Administrator)) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

try {
    # Path to the XML file (same directory as script)
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $xmlPath = Join-Path $scriptDir "MSEdgeOnLogon.xml"
    
    # Check if XML file exists
    if (-not (Test-Path $xmlPath)) {
        Write-Host "Error: XML file not found at $xmlPath" -ForegroundColor Red
        Write-LogEntry "Error: XML file not found at $xmlPath"
        exit 1
    }
    
    Write-Host "Found XML file: $xmlPath" -ForegroundColor Cyan
    
    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName "MSEdgeOnLogon" -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        Write-Host "Scheduled task 'MSEdgeOnLogon' already exists." -ForegroundColor Yellow
        $confirmation = Read-Host "Do you want to replace it? (yes/no)"
        
        if ($confirmation -eq "yes") {
            Unregister-ScheduledTask -TaskName "MSEdgeOnLogon" -Confirm:$false
            Write-Host "Existing task removed." -ForegroundColor Yellow
            Write-LogEntry "Removed existing MSEdgeOnLogon task"
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Cyan
            exit 0
        }
    }
    
    # Get LibUser for the task
    $libUser = Get-LocalUser -Name "LibUser" -ErrorAction Stop
    $userSID = $libUser.SID.Value
    Write-Host "LibUser SID: $userSID" -ForegroundColor Cyan
    
    # Register the scheduled task from XML
    Register-ScheduledTask -Xml (Get-Content $xmlPath | Out-String) -TaskName "MSEdgeOnLogon" -User "LibUser" -ErrorAction Stop
    
    Write-Host "`n[OK] Scheduled task 'MSEdgeOnLogon' created successfully from XML!" -ForegroundColor Green
    Write-LogEntry "MSEdgeOnLogon scheduled task imported from XML successfully"
    
    # Display task details
    $task = Get-ScheduledTask -TaskName "MSEdgeOnLogon"
    Write-Host "`nTask Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($task.TaskName)" -ForegroundColor White
    Write-Host "  State: $($task.State)" -ForegroundColor White
    Write-Host "  User: LibUser" -ForegroundColor White
    Write-Host "  Description: $($task.Description)" -ForegroundColor White
    
    Write-Host "`nNote: Ensure the file exists at:" -ForegroundColor Yellow
    Write-Host "  C:\Users\LibUser\Desktop\Conditions_of_Use_for_Public_Access_PCs.html" -ForegroundColor Yellow
    
    Write-Host "`nLog file: C:\applications\CreateMSEdgeTask.log" -ForegroundColor Cyan
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-LogEntry "Error creating task: $($_.Exception.Message)"
    exit 1
}

# Example usage:
<#
# Create the scheduled task from XML
.\SchedMSEdgeOnLogon.ps1

# Prerequisites:
# - MSEdgeOnLogon.xml must be in the same directory as the script
# - LibUser account must exist
# - The HTML file must exist at: C:\Users\LibUser\Desktop\Conditions_of_Use_for_Public_Access_PCs.html

# To verify the task was created:
Get-ScheduledTask -TaskName "MSEdgeOnLogon"

# To manually run the task:
Start-ScheduledTask -TaskName "MSEdgeOnLogon"

# To remove the task:
Unregister-ScheduledTask -TaskName "MSEdgeOnLogon" -Confirm:$false
#>