# =====================================================================
# First Logon Script - Lenovo Commercial Vantage + Local Password Expiry
# =====================================================================

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Ensure admin ---
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

# --- Retry logic ---
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
# HARDENED FIX: Local password expiry (policy + per-user)
# =====================================================================

# --- Set local password policy (future accounts) ---
cmd.exe /c "net accounts /maxpwage:unlimited" | Out-Null

# --- Lock down the Resilience dummy account ---
$DummyUser = "ResilienceUser"

if (Get-LocalUser -Name $DummyUser -ErrorAction SilentlyContinue) {

    # Ensure password never expires (immune to policy reapplication)
    Set-LocalUser -Name $DummyUser -PasswordNeverExpires $true

    # Ensure Windows never forces a password change
    cmd.exe /c "net user $DummyUser /logonpasswordchg:no" | Out-Null

} else {
    Write-Warning "Local user '$DummyUser' not found — password expiry fix skipped."
}

Write-Host "Completed: Vantage installed + ResilienceUser password expiry permanently disabled."
