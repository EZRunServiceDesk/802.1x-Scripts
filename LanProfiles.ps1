# Outputs profile info for 802.1x, helps with troubelshooting 

# === Configuration ===
# Set your interface alias here (e.g. "Ethernet", "Local Area Connection")
$InterfaceAlias = "Ethernet"

# Build timestamp (e.g. 2025-04-25_14-45-30)
$timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Prepare output directory and file path
$outDir   = "C:\Logs\Dot1x"
$fileName = "Dot1x_Lan_Profiles_$timestamp.txt"
$filePath = Join-Path $outDir $fileName

# Ensure the directory exists
if (-not (Test-Path $outDir)) {
    New-Item -Path $outDir -ItemType Directory -Force | Out-Null
}

#
# Now capture each heading and command output to BOTH console and file
#

# 1) Interface Status header + output
"--- 802.1X Interface Status (netsh) ---" `
    | Tee-Object -FilePath $filePath
netsh lan show interfaces `
    | Tee-Object -FilePath $filePath -Append

# blank line separator
"" `
    | Tee-Object -FilePath $filePath -Append

# 2) LAN Profiles header + output
"--- 802.1X LAN Profiles (netsh) ---" `
    | Tee-Object -FilePath $filePath -Append
netsh lan show profiles interface="$InterfaceAlias" `
    | Tee-Object -FilePath $filePath -Append

# final message
"`nOutput saved to: $filePath" `
    | Tee-Object -FilePath $filePath -Append
