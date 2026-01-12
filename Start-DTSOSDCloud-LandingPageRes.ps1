# --- OS choices
$OSName       = 'Windows 11 25H2 x64'
$OSEdition    = 'Pro'
$OSActivation = 'Retail'
$OSLanguage   = 'en-gb'

# --- OSDCloud global config
$Global:MyOSDCloud = [ordered]@{
    Restart               = $false
    RecoveryPartition     = $true
    OEMActivation         = $true
    WindowsUpdate         = $true
    WindowsUpdateDrivers  = $true
    WindowsDefenderUpdate = $true
    SetTimeZone           = $true
    ClearDiskConfirm      = $false
    ShutdownSetupComplete = $false
    SyncMSUpCatDriverUSB  = $true
    CheckSHA1             = $true
}

Write-Host "`nStarting OSDCloud for Windows 11 Professional - Resilience Build`n" -ForegroundColor Yellow

# 1) Deploy the OS (no auto-restart)
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

# 2) Locate source unattend.xml on any attached drive under \OSDCloud\Config\OOBEDeploy\
$SourceUnattend = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $p = Join-Path $_.Root 'OSDCloud\Config\OOBEDeploy\unattend.xml'
    if (Test-Path $p) { $p }
} | Select-Object -First 1

if (-not $SourceUnattend) {
    Write-Warning "unattend.xml not found under <Drive>:\OSDCloud\Config\OOBEDeploy\ on any attached drive."
} else {
    # 3) Find the target Windows partition (offline OS we just applied)
    $TargetRoot = Get-PSDrive -PSProvider FileSystem |
        Where-Object { $_.Name -ne 'X' -and (Test-Path (Join-Path $_.Root 'Windows\System32\Config\SYSTEM')) } |
        Select-Object -ExpandProperty Root -First 1

    if (-not $TargetRoot) { throw "Could not locate the target Windows partition." }

    $PantherDir     = Join-Path $TargetRoot 'Windows\Panther'
    $PantherUndir   = Join-Path $PantherDir 'Unattend'
    $Dest1          = Join-Path $PantherDir   'unattend.xml'                       # C:\Windows\Panther\unattend.xml
    $Dest2          = Join-Path $PantherUndir 'Unattend.xml'                       # C:\Windows\Panther\Unattend\Unattend.xml

    New-Item -ItemType Directory -Path $PantherDir   -Force | Out-Null
    New-Item -ItemType Directory -Path $PantherUndir -Force | Out-Null

    # Copy to both common search paths (belt and braces)
    Copy-Item $SourceUnattend $Dest1 -Force
    Copy-Item $SourceUnattend $Dest2 -Force
    Write-Host "Staged unattend.xml to:`n  $Dest1`n  $Dest2"

    # 4) Set the offline registry pointer HKLM\SYSTEM\Setup\UnattendFile -> Panther\Unattend\Unattend.xml
    $OfflineSystemHive = Join-Path $TargetRoot 'Windows\System32\Config\SYSTEM'
    reg.exe load HKLM\OFFSYS "$OfflineSystemHive" | Out-Null
    reg.exe add "HKLM\OFFSYS\Setup" /v UnattendFile /t REG_SZ /d "$Dest2" /f | Out-Null
    reg.exe unload HKLM\OFFSYS | Out-Null
    Write-Host "Set offline registry UnattendFile -> $Dest2"
}

# 5) Reboot to continue setup/OOBE using your answer file
wpeutil reboot
