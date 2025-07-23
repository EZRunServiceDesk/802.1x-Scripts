#This will make a scheduled task during At Startup to check logs after waiting 10 mins and see if it finds any 802.1X failure Event IDs. If so it will restart dot3svc

$WaitBeforeChecking = 601

$taskName = "802.1X Auth Failure Recovery"
$scriptFolder = "C:\Scripts"
$scriptPath = "$scriptFolder\CheckAuthFail.ps1"

# Ensure the $scriptFolder folder exists
if (-not (Test-Path $scriptFolder)) {
    New-Item -Path $scriptFolder -ItemType Directory -Force
}

# Full script content with event details logged
$scriptContent = @"
Start-Sleep -Seconds $WaitBeforeChecking
`$EventIDsToCheck = @(1101, 1200, 1208, 1102, 1104)   # <=== Add or remove relevant 802.1X failure Event IDs
`$scriptFolder = `"$scriptFolder`"
`$logPath = Join-Path `$scriptFolder 'dot3svc-log.txt'

`$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
`$foundEvents = @()

foreach (`$id in `$EventIDsToCheck) {
    `$events = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        ProviderName = 'Wired AutoConfig'
        Id = `$id
        StartTime = (Get-Date).AddMinutes(-10)
    } -ErrorAction SilentlyContinue

    if (`$events) {
        `$foundEvents += `$events
    }
}

if (`$foundEvents.Count -gt 0) {
    "`$timestamp - Found 802.1X authentication failure event(s). Restarting dot3svc..." | Out-File -FilePath `$logPath -Append -Encoding utf8
    foreach (`$evt in `$foundEvents) {
        "`$($evt.TimeCreated) - ID: `$($evt.Id) - `$($evt.Message -replace '[\r\n]+',' ')" | Out-File -FilePath `$logPath -Append -Encoding utf8
    }
    Restart-Service -Name "dot3svc" -Force
    Write-EventLog -LogName Application -Source "PowerShell" -EntryType Warning -EventId 1001 -Message "802.1X Authentication failure detected. Restarted dot3svc."
} else {
    "`$timestamp - No 802.1X failure events found. dot3svc not restarted." | Out-File -FilePath `$logPath -Append -Encoding utf8
}
"@

# Save to $scriptFolder
Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8

# Ensure PowerShell event source exists
if (-not [System.Diagnostics.EventLog]::SourceExists("PowerShell")) {
    New-EventLog -LogName Application -Source "PowerShell"
}

# Scheduled Task action and trigger
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger -AtStartup

# Remove old task if needed
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Register the new task
Register-ScheduledTask -TaskName $taskName `
    -Trigger $trigger `
    -Action $action `
    -RunLevel Highest `
    -User "SYSTEM" `
    -Description "Restart dot3svc if any 802.1X failure event is found. Log output includes full event info."
