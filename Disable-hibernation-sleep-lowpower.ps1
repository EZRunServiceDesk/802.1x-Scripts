<#
.SYNOPSIS
    Disable hibernation & sleep, turn off Fast Startup, and disable NIC power-down on Ethernet adapters.

.DESCRIPTION
    • Disables hibernation (`powercfg /hibernate off`) :contentReference[oaicite:0]{index=0}  
    • Disables standby (sleep) for AC/DC power :contentReference[oaicite:1]{index=1}  
    • Clears “Allow the computer to turn off this device to save power” by setting `PnPCapabilities=24` on all Ethernet adapters :contentReference[oaicite:2]{index=2}  
    • Disables Fast Startup by setting `HiberbootEnabled=0` in the registry :contentReference[oaicite:3]{index=3}

.EXAMPLE
    .\Disable-PowerSettings.ps1
#>

# Ensure script is running elevated
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator."
    exit 1
}

# === Variables ===
# Class GUID for network adapters
$classGUID = '{4D36E972-E325-11CE-BFC1-08002bE10318}'
$registryBase = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classGUID"

# GUIDs for disabling standby (sleep)
$standbySubGuid    = '238c9fa8-0aad-41ed-83f4-97be242c8f20'  # SUB_SLEEP
$standbySettingGuid = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'  # STANDBYIDLE

# === Disable Hibernation ===
Write-Host "Disabling hibernation..."
powercfg /hibernate off
# :contentReference[oaicite:4]{index=4}

# === Disable Sleep (Standby) ===
Write-Host "Disabling sleep (standby) on AC and DC..."
powercfg /setacvalueindex SCHEME_CURRENT $standbySubGuid $standbySettingGuid 0
powercfg /setdcvalueindex SCHEME_CURRENT $standbySubGuid $standbySettingGuid 0
powercfg /S SCHEME_CURRENT
# :contentReference[oaicite:5]{index=5}

# === Turn Off Fast Startup ===
Write-Host "Disabling Fast Startup..."
$fastBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
Set-ItemProperty -Path $fastBootRegPath -Name 'HiberbootEnabled' -Value 0 -Type DWord -Force
# :contentReference[oaicite:6]{index=6}

# === Disable NIC Power-down on Ethernet Adapters ===
Write-Host "Disabling NIC power management on Ethernet adapters..."
Get-ChildItem -Path $registryBase -ErrorAction SilentlyContinue | ForEach-Object {
    $keyPath = $_.PsPath
    try {
        $desc = (Get-ItemProperty -Path $keyPath -Name 'DriverDesc' -ErrorAction Stop).DriverDesc
        if ($desc -match 'Ethernet') {
            # 24 (0x18) ensures "Allow the computer to turn off this device to save power" is unchecked
            Set-ItemProperty -Path $keyPath -Name 'PnPCapabilities' -Value 24 -Type DWord -Force
            Write-Host "  • $desc — PnPCapabilities set to 24"
        }
    } catch {
        # skip keys without DriverDesc
    }
}
# :contentReference[oaicite:7]{index=7}

Write-Host "All done. Please reboot to ensure all settings take effect."
