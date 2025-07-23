# restarts dot3svc service 

try {
    Write-Host "Stopping dot3svc..."
    Stop-Service -Name dot3svc -Force -ErrorAction Stop
    Write-Host "dot3svc stopped successfully."
}
catch {
    Write-Warning "Failed to stop dot3svc: $_"
}

Start-Sleep -Seconds 2  # Optional pause

try {
    Write-Host "Starting dot3svc..."
    Start-Service -Name dot3svc -ErrorAction Stop
    Write-Host "dot3svc started successfully."
}
catch {
    Write-Warning "Failed to start dot3svc: $_"
}
