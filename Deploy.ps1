#===========================================================
# Deploy.ps1
# Simple PowerShell-based Windows deployment
#===========================================================

$ImageFile   = "\\DeployServer\Images\Windows11.wim"
$DriverRoot  = "\\DeployServer\Drivers"
$DiskNumber  = 0

Write-Host "Starting deployment..."

#-----------------------------------------------------------
# 1. Partition Disk (UEFI)
#-----------------------------------------------------------

$diskpartScript = @"
select disk $DiskNumber
clean
convert gpt

create partition efi size=100
format quick fs=fat32 label="System"
assign letter=S

create partition msr size=16

create partition primary
format quick fs=ntfs label="Windows"
assign letter=C
exit
"@

$diskpartScript | Out-File X:\diskpart.txt -Encoding ASCII
diskpart /s X:\diskpart.txt

Write-Host "Disk partitioning complete."

#-----------------------------------------------------------
# 2. Apply Windows Image
#-----------------------------------------------------------

Write-Host "Applying Windows image..."

dism /Apply-Image /ImageFile:$ImageFile /Index:1 /ApplyDir:C:\

Write-Host "Windows image applied."

#-----------------------------------------------------------
# 3. Detect Hardware Model
#-----------------------------------------------------------

$Model = (Get-CimInstance Win32_ComputerSystem).Model
Write-Host "Detected device model: $Model"

$DriverPath = Join-Path $DriverRoot $Model

#-----------------------------------------------------------
# 4. Inject Drivers
#-----------------------------------------------------------

if (Test-Path $DriverPath) {

    Write-Host "Injecting drivers from $DriverPath"

    dism /Image:C:\ /Add-Driver /Driver:$DriverPath /Recurse

}
else {

    Write-Host "No specific driver pack found."
    Write-Host "Continuing without driver injection."

}

#-----------------------------------------------------------
# 5. Install Boot Files
#-----------------------------------------------------------

Write-Host "Configuring boot files..."

bcdboot C:\Windows /s S: /f UEFI

Write-Host "Boot files configured."

#-----------------------------------------------------------
# 6. Optional Post-Install Scripts
#-----------------------------------------------------------

$PostScript = "\\DeployServer\Scripts\SetupComplete.ps1"

if (Test-Path $PostScript) {

    Write-Host "Copying post-install script..."

    $Dest = "C:\Windows\Setup\Scripts"

    if (!(Test-Path $Dest)) {
        New-Item -Path $Dest -ItemType Directory
    }

    Copy-Item $PostScript "$Dest\SetupComplete.ps1"

}

#-----------------------------------------------------------
# 7. Finish
#-----------------------------------------------------------

Write-Host "Deployment complete."
Write-Host "Rebooting..."

Restart-Computer
