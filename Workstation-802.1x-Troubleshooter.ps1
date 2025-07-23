<#
.SYNOPSIS
    Diagnose common 802.1X authentication issues on a wired interface.

.DESCRIPTION
    Checks interface existence, 802.1X status, Event Logs, certificate availability & chain,
    applied GPO settings (RSOP & registry), and adapter’s 802.1X WMI settings.

.NOTES
    - To change which adapter to test, set the environment or PS variable $InterfaceAliasPS.
    - Logs and transcripts are saved to C:\Temp\Dot1X with a timestamp.
#>

# === Configuration ===
# Name of the network interface to check (provided via $InterfaceAliasPS)
$InterfaceAlias = "Ethernet"

# Output directory for logs and transcript
$OutputDir = 'C:\Logs\Dot1X'

# Generate timestamp for file naming
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

Write-Host "===== 802.1X Diagnostic Script =====" -ForegroundColor Cyan

# Prepare output directory and start transcript
if (!(Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}
$TransFile = Join-Path $OutputDir "Diagnose-8021X_$Timestamp.txt"
Start-Transcript -Path $TransFile -Force

# 0. Ensure running as Admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Warning 'This script must be run as Administrator.'
    Stop-Transcript
    exit 1
}

# 1. Verify adapter exists
Write-Host "`n--- 1. Adapter Check ---"
$adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue
if (-not $adapter) {
    Write-Host "ERROR: Interface '$InterfaceAlias' not found." -ForegroundColor Red
    Stop-Transcript
    exit 1
} else {
    Write-Host "Interface '$InterfaceAlias' found: Status=$($adapter.Status), MAC=$($adapter.MacAddress)"
}

# 2. 802.1X status via netsh
Write-Host "`n--- 2. 802.1X Interface Status (netsh) ---"
netsh lan show interfaces |
    Tee-Object -FilePath (Join-Path $OutputDir "Netsh-Interfaces_$Timestamp.txt")

# 2b. List wired 802.1X profiles
Write-Host "`n--- 2b. 802.1X LAN Profiles (netsh) ---"
netsh lan show profiles interface="$InterfaceAlias" |
    Tee-Object -FilePath (Join-Path $OutputDir "Netsh-Profiles_$Timestamp.txt")

# 3. Recent errors in Dot3Svc & EapHost logs
Write-Host "`n--- 3. Event Log Errors (Level=Error) ---"
$dot3Log = 'Microsoft-Windows-Dot3Svc/Operational'
if (Get-WinEvent -ListLog $dot3Log -ErrorAction SilentlyContinue) {
    Write-Host "Querying $dot3Log"
    Get-WinEvent -FilterHashtable @{ LogName = $dot3Log; Level = 2 } -MaxEvents 5 |
        Tee-Object -FilePath (Join-Path $OutputDir "Dot3Svc-Errors_$Timestamp.txt") |
        Format-Table TimeCreated, Id, Message -AutoSize
} else {
    Write-Warning "Event log '$dot3Log' not found. Skipping Dot3Svc log query."
}

$eapLog = 'Microsoft-Windows-EapHost/Operational'
if (Get-WinEvent -ListLog $eapLog -ErrorAction SilentlyContinue) {
    Write-Host "Querying $eapLog"
    Get-WinEvent -FilterHashtable @{ LogName = $eapLog; Level = 2 } -MaxEvents 5 |
        Tee-Object -FilePath (Join-Path $OutputDir "EapHost-Errors_$Timestamp.txt") |
        Format-Table TimeCreated, Id, Message -AutoSize
} else {
    Write-Warning "Event log '$eapLog' not found. Skipping EapHost log query."
}

# 4. Certificate inventory & chain validation
Write-Host "`n--- 4. Certificate Check (Client Authentication EKU) ---"
function Test-CertChain {
    param($Cert)
    $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
    if ($chain.Build($Cert)) {
        Write-Host "    Chain valid"
    } else {
        Write-Warning "    Chain issues:"
        $chain.ChainStatus | ForEach-Object { Write-Warning ("      " + $_.StatusInformation.Trim()) }
    }
}
foreach ($store in @('LocalMachine','CurrentUser')) {
    $path = "Cert:\$store\My"
    Write-Host " Store: $path"
    $certs = Get-ChildItem -Path $path -ErrorAction SilentlyContinue |
        Where-Object { $_.EnhancedKeyUsageList.FriendlyName -contains 'Client Authentication' }
    if ($certs) {
        foreach ($c in $certs) {
            Write-Host "  $($c.Subject)  Thumb=$($c.Thumbprint)  HasPrivateKey=$($c.HasPrivateKey)"
            Test-CertChain $c
        }
    } else {
        Write-Warning "  No Client-Auth certs found in $path"
    }
}

# 5. Wired 802.1X Policy (GPO & Registry)
Write-Host "`n--- 5. Wired 802.1X Policy (GPO & Registry) ---"
$gpoutput = gpresult /Scope Computer /V 2>&1
if ($gpoutput -match '802\.1X|Wired') {
    $gpoutput |
        Tee-Object -FilePath (Join-Path $OutputDir "GpResult_$Timestamp.txt") |
        Select-String -Pattern 'Wired','802.1X'
} else {
    Write-Warning "No wired-802.1X settings returned by gpresult."
}

# Check registry-based policy
$policyKey = 'HKLM:\Software\Policies\Microsoft\Windows\WiredAutoConfig'
if (Test-Path $policyKey) {
    Write-Host "Registry settings under \${policyKey}:"
    Get-ItemProperty -Path $policyKey |
        Tee-Object -FilePath (Join-Path $OutputDir "Registry-Policy_$Timestamp.txt") |
        Format-List
} else {
    Write-Warning "No wired 802.1X policy registry settings found at \${policyKey}."
}

# 6. Adapter’s 802.1X WMI/CIM settings
Write-Host "`n--- 6. WMI: MSFT_NetAdapter8021xSettingData ---"
$namespace = 'root/StandardCimv2'
$className = 'MSFT_NetAdapter8021xSettingData'
if (Get-CimClass -Namespace $namespace -ClassName $className -ErrorAction SilentlyContinue) {
    Get-CimInstance -Namespace $namespace -ClassName $className -ErrorAction Stop |
      Where-Object { $_.Name -eq $InterfaceAlias } |
      Tee-Object -FilePath (Join-Path $OutputDir "WMI-AdapterSettings_$Timestamp.txt") |
      Format-List *
} else {
    Write-Warning "CIM class '\${className}' not found in namespace '\${namespace}'. Skipping adapter settings check."
}

# Stop transcript and finish
Stop-Transcript
Write-Host "`nDiagnosis complete. Review logs under $OutputDir." -ForegroundColor Green
