# Create MSEdge On Logon Scheduled Task
# This script creates a scheduled task that launches Microsoft Edge on user logon
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
Write-Host "Create MSEdge On Logon Scheduled Task" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Check if running as Administrator
if (-not (Test-Administrator)) {
    Write-Host "This script requires Administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

try {
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
    
    # Get LibUser SID
    $libUser = Get-LocalUser -Name "LibUser" -ErrorAction Stop
    $userSID = $libUser.SID.Value
    Write-Host "LibUser SID: $userSID" -ForegroundColor Cyan
    
    # Define task action
    $action = New-ScheduledTaskAction `
        -Execute "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
        -Argument "--start-maximized --new-window C:\Users\LibUser\Desktop\Conditions_of_Use_for_Public_Access_PCs.html"
    
    # Define trigger (10 seconds after logon)
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $trigger.Delay = "PT10S"  # 10 second delay
            
        # Define principal (run as LibUser with least privilege)
        $principal = New-ScheduledTaskPrincipal `
            -UserId $userSID `
            -LogonType Interactive `
            -RunLevel Limited
        
        # Define settings
        $settings = New-ScheduledTaskSettingsSet `
            -MultipleInstances IgnoreNew `
            -AllowHardTerminate `
            -StartWhenAvailable:$false `
            -RunOnlyIfNetworkAvailable:$false `
            -AllowStartOnDemand `
            -Enabled `
            -Hidden:$false `
            -RunOnlyIfIdle:$false `
            -WakeToRun:$false `
            -ExecutionTimeLimit (New-TimeSpan -Hours 72) `
            -Priority 7
        
        # Configure battery settings separately (not available as cmdlet parameters)
        $settings.DisallowStartIfOnBatteries = $true
        $settings.StopIfGoingOnBatteries = $true
        
        # Register the scheduled task
        $task = Register-ScheduledTask `
            -TaskName "MSEdgeOnLogon" `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Settings $settings `
            -Description "Launches Microsoft Edge with Terms of Use page when LibUser logs in"
        
    if ($task) {
        Write-Host "`n[OK] Scheduled task 'MSEdgeOnLogon' created successfully!" -ForegroundColor Green
        Write-LogEntry "MSEdgeOnLogon scheduled task created successfully"
        
        # Display task details
        Write-Host "`nTask Details:" -ForegroundColor Cyan
        Write-Host "  Name: MSEdgeOnLogon" -ForegroundColor White
        Write-Host "  Trigger: At logon (10 second delay)" -ForegroundColor White
        Write-Host "  User: LibUser ($userSID)" -ForegroundColor White
        Write-Host "  Action: Launch Edge with Terms of Use" -ForegroundColor White
        Write-Host "  Status: Enabled" -ForegroundColor White
        
        Write-Host "`nNote: Ensure the file exists at:" -ForegroundColor Yellow
        Write-Host "  C:\Users\LibUser\Desktop\Conditions_of_Use_for_Public_Access_PCs.html" -ForegroundColor Yellow
    } else {
        Write-Host "Failed to create scheduled task." -ForegroundColor Red
        Write-LogEntry "Failed to create MSEdgeOnLogon task"
        exit 1
    }
    
    Write-Host "`nLog file: C:\applications\CreateMSEdgeTask.log" -ForegroundColor Cyan
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-LogEntry "Error creating task: $($_.Exception.Message)"
    exit 1
}

# Example usage:
<#
# Create the scheduled task
.\CreateMSEdgeTask.ps1

# The task will:
# - Run when LibUser logs in
# - Wait 10 seconds after logon
# - Launch Microsoft Edge in maximized mode
# - Open the Terms of Use HTML file from LibUser's desktop

# Prerequisites:
# - LibUser account must exist
# - The HTML file must exist at: C:\Users\LibUser\Desktop\Conditions_of_Use_for_Public_Access_PCs.html

# To verify the task was created:
Get-ScheduledTask -TaskName "MSEdgeOnLogon"

# To manually run the task:
Start-ScheduledTask -TaskName "MSEdgeOnLogon"

# To remove the task:
Unregister-ScheduledTask -TaskName "MSEdgeOnLogon" -Confirm:$false
#>