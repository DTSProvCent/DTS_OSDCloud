# ======================================
# Schedule Lenovo Vantage Install (GitHub)
# ======================================
Write-Output "Creating scheduled task [InstallLenovoVantage] to run from GitHub at first logon"

$TaskName = "InstallLenovoVantage"

# Delete any existing task
schtasks.exe /delete /tn $TaskName /f > $null 2>&1

# Build command line safely
$Command = 'powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "Invoke-Expression (Invoke-RestMethod ''https://raw.githubusercontent.com/RobesNo1/DTS_OSDCloud/refs/heads/main/Install-Vantage.ps1'')"'

# Create scheduled task (runs at next logon, elevated, deletes itself)
$Action   = New-ScheduledTaskAction -Execute "powershell.exe" `
             -Argument '-ExecutionPolicy Bypass -NoProfile -Command "Invoke-Expression (Invoke-RestMethod ''https://raw.githubusercontent.com/RobesNo1/DTS_OSDCloud/refs/heads/main/Install-Vantage.ps1'')"'
$Trigger  = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Force
