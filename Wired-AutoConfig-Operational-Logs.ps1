# List the last 24 hours logs for Wired-AutoConfig Operational. This will output to console and save logs to $outputDir location 
$LastHours = 24

# Define the log name and output directory
$logName = 'Microsoft-Windows-Wired-AutoConfig/Operational'
$outputDir = 'C:\Logs\Wired-AutoConfig'

# Create the output directory if it doesn't exist
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force
}

# Calculate the time 24 hours ago
$startTime = (Get-Date).AddHours(-$LastHours)

# Get the logs from the last 24 hours
$events = Get-WinEvent -LogName $logName | Where-Object { $_.TimeCreated -ge $startTime }

# Output to console
$events |
    Select-Object TimeCreated, Id, LevelDisplayName, Message |
    Format-List

# Create a timestamped file
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$outputFile = Join-Path $outputDir "WiredAutoConfigLogs_$timestamp.txt"

# Save to file
$events |
    Select-Object TimeCreated, Id, LevelDisplayName, Message |
    Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "`nLogs saved to: $outputFile"
