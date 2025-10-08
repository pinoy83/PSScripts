# -------------------------------
# Configuration
# -------------------------------
$Apps = @(
    @{ Name = "Epic Games"; Id = "XP99VR1BPSBQJ2" },
    @{ Name = "OBS Studio"; Id = "XPFFH613W8V6LV"; PackageName = "*OBS*" }

)

$LogFile = "C:\Applications\StoreAppAdminInstallLog.txt"  # Change path as needed

# Ensure log directory exists
$LogDir = Split-Path $LogFile
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force
}

# -------------------------------
# Logging function
# -------------------------------
function Write-Log {
    param([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "$TimeStamp - $Message"
    Add-Content -Path $LogFile -Value $Entry
    Write-Output $Entry
}

# -------------------------------
# Main installation loop
# -------------------------------
foreach ($app in $Apps) {
    $Name = $app.Name
    $Id = $app.Id

    # Check if installed
    $Installed = Get-AppxPackage -Name $Name -ErrorAction SilentlyContinue
    if ($Installed) {
        Write-Log "$Name is already installed. Version: $($Installed.Version)"
    } else {
        Write-Log "$Name not found. Installing via winget..."
        try {
            winget install --id $Id --source msstore --silent --accept-package-agreements --accept-source-agreements
            Write-Log "$Name installed successfully via winget."
        } catch {
            $errorMsg = $_
            Write-Log "Installation failed for $Name $errorMsg"

        }
    }
}

Write-Log "Script finished."
