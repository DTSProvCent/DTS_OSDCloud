# =======================
# Custom OSDCloud Landing Page (v1.5 - using Export-LocalServerCopy.ps1)
# =======================

# --- OS Selection Variables ---
$OSName       = 'Windows 11 25H2 x64'
$OSEdition    = 'Enterprise'
$OSActivation = 'Retail'
$OSLanguage   = 'en-gb'

# --- Global OSDCloud Settings ---
$Global:MyOSDCloud = [ordered]@{
    Restart                  = $false
    RecoveryPartition        = $true
    OEMActivation            = $true
    WindowsUpdate            = $true
    WindowsUpdateDrivers     = $true
    WindowsDefenderUpdate    = $true
    SetTimeZone              = $true
    ClearDiskConfirm         = $false
    ShutdownSetupComplete    = $false
    SyncMSUpCatDriverUSB     = $true
    CheckSHA1                = $true
}

# --- Info Banner ---
Write-Host "`nStarting OSDCloud for $OSEdition..." -ForegroundColor Yellow
Write-Host ""

# --- Start Deployment ---
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

# --- Post Deployment: SetupComplete Injection ---
Write-Host "`nInjecting SetupComplete.cmd and Export-LocalServerCopy.ps1 from WinPE (X:)..." -ForegroundColor Cyan

# Source from WinPE (RAMDisk)
$sourceFolder             = "X:\OSDCloud"
$setupCmdSource           = "$sourceFolder\SetupComplete.cmd"
$exportScriptSource       = "$sourceFolder\Export-LocalServerCopy.ps1"

# Target in deployed OS
$targetRoot               = "$env:SystemDrive"
$setupScriptPath          = Join-Path $targetRoot "Windows\Setup\Scripts"
$osdCloudFolder           = Join-Path $targetRoot "OSDCloud"
$setupCmdTarget           = Join-Path $setupScriptPath "SetupComplete.cmd"
$exportScriptTarget       = Join-Path $osdCloudFolder "Export-LocalServerCopy.ps1"

# Create required folders
if (-not (Test-Path $setupScriptPath)) {
    New-Item -ItemType Directory -Path $setupScriptPath -Force | Out-Null
    Write-Host "✔ Created folder: $setupScriptPath"
}

if (-not (Test-Path $osdCloudFolder)) {
    New-Item -ItemType Directory -Path $osdCloudFolder -Force | Out-Null
    Write-Host "✔ Created folder: $osdCloudFolder"
}

# Copy SetupComplete.cmd
if (Test-Path $setupCmdSource) {
    Copy-Item -Path $setupCmdSource -Destination $setupCmdTarget -Force
    Write-Host "✔ SetupComplete.cmd copied to $setupScriptPath"
} else {
    Write-Host "⚠ SetupComplete.cmd not found at $setupCmdSource" -ForegroundColor Red
}

# Copy Export-LocalServerCopy.ps1
if (Test-Path $exportScriptSource) {
    Copy-Item -Path $exportScriptSource -Destination $exportScriptTarget -Force
    Write-Host "✔ Export-LocalServerCopy.ps1 copied to $osdCloudFolder"
} else {
    Write-Host "⚠ Export-LocalServerCopy.ps1 not found at $exportScriptSource" -ForegroundColor Red
}

# --- Reboot ---
Write-Host "`nDeployment complete. Press any key to reboot into OOBE..." -ForegroundColor Green
[void][System.Console]::ReadKey($true)
wpeutil reboot

