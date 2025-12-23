# =====================================================================
# First Logon Script - Lenovo Commercial Vantage + Local Password Expiry
# =====================================================================

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Ensure admin (Vantage install + password policy typically need elevation) ---
if (-not (Test-IsAdmin)) {
    Write-Host "Not running elevated. Re-run this script as Administrator (or deploy via SetupComplete / Scheduled Task as SYSTEM)."
    exit 1
}

# --- Support folder ---
$SupportPath = "C:\Support"
if (-not (Test-Path $SupportPath)) {
    New-Item -ItemType Directory -Path $SupportPath -Force | Out-Null
}

# --- Download Lenovo Commercial Vantage ZIP ---
$VantageZipUrl  = "https://download.lenovo.com/pccbbs/thinkvantage_en/metroapps/Vantage/LenovoCommercialVantage_20.2506.39.0_v17.zip"
$VantageZipPath = Join-Path $SupportPath "LenovoCommercialVantage.zip"

# Basic retry (network flakiness at first logon is common)
$maxAttempts = 3
for ($i = 1; $i -le $maxAttempts; $i++) {
    try {
        Invoke-WebRequest -Uri $VantageZipUrl -OutFile $VantageZipPath
        break
    } catch {
        if ($i -eq $maxAttempts) { throw }
        Start-Sleep -Seconds (5 * $i)
    }
}

# --- Extract and install ---
$ExtractPath = Join-Path $SupportPath "CommercialVantage"
if (Test-Path $ExtractPath) { Remove-Item -Recurse -Force $ExtractPath }
Expand-Archive -Path $VantageZipPath -DestinationPath $ExtractPath -Force

$Installer = Join-Path $ExtractPath "VantageInstaller.exe"
if (Test-Path $Installer) {
    Start-Process $Installer -ArgumentList "Install -Vantage" -Wait
} else {
    throw "VantageInstaller.exe not found at: $Installer"
}

# =====================================================================
# Set local password expiry to NEVER
# =====================================================================

# 1) Local password policy: Maximum password age = Unlimited
# (This affects LOCAL accounts on the device, not your AD/AzureAD tenant policies)
cmd.exe /c "net accounts /maxpwage:unlimited" | Out-Null

# 2) Set PasswordNeverExpires on all local users (exclude built-in service accounts)
$Exclude = @('Administrator','DefaultAccount','Guest','WDAGUtilityAccount')

try {
    Get-LocalUser | Where-Object { $Exclude -notcontains $_.Name } | ForEach-Object {
        Set-LocalUser -Name $_.Name -PasswordNeverExpires $true
    }
} catch {
    # If Get-LocalUser isn't available for some reason, at least the policy change above is applied.
    Write-Warning "Could not enumerate local users (Get-LocalUser). Policy maxpwage is still set to unlimited."
}

Write-Host "Completed: Vantage installed + local password expiry set to never."
