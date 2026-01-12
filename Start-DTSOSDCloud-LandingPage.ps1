# Set Windows OS variables
$OSName = 'Windows 11 25H2 x64'
$OSEdition = 'Enterprise'
$OSActivation = 'Retail'
$OSLanguage = 'en-gb'

# Set OSDCloud global configuration
$Global:MyOSDCloud = [ordered]@{
    Restart = $false
    RecoveryPartition = $true
    OEMActivation = $true
    WindowsUpdate = $true
    WindowsUpdateDrivers = $true
    WindowsDefenderUpdate = $true
    SetTimeZone = $true
    ClearDiskConfirm = $false
    ShutdownSetupComplete = $false
    SyncMSUpCatDriverUSB = $true
    CheckSHA1 = $true
}

# Optional banner
Write-Host ""
Write-Host "Starting OSDCloud for Windows 11 Enterprise..." -ForegroundColor Yellow
Write-Host ""

# Start the deployment
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

# Reboot when complete
wpeutil reboot

