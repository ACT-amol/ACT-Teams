# PowerShell System Health Check Script

function Get-SystemHealthReport {
    Write-Host "--- System Health Report ---" -ForegroundColor Green

    # 1. CPU Usage
    Write-Host "`n[1] CPU Usage:" -ForegroundColor Yellow
    try {
        $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
        Write-Host "Current CPU Usage: $($cpu.CounterSamples.CookedValue)%`n"
    }
    catch {
        Write-Host "Could not retrieve CPU usage: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 2. RAM Usage
    Write-Host "[2] RAM Usage:" -ForegroundColor Yellow
    try {
        $ram = Get-WmiObject win32_OperatingSystem
        $totalRamGB = [Math]::Round($ram.TotalVisibleMemorySize / 1GB, 2)
        $freeRamGB = [Math]::Round($ram.FreePhysicalMemory / 1GB, 2)
        $usedRamGB = [Math]::Round($totalRamGB - $freeRamGB, 2)
        $ramUsagePercentage = [Math]::Round(($usedRamGB / $totalRamGB) * 100, 2)

        Write-Host "Total RAM: $($totalRamGB) GB"
        Write-Host "Free RAM: $($freeRamGB) GB"
        Write-Host "Used RAM: $($usedRamGB) GB ($($ramUsagePercentage)%)`n"
    }
    catch {
        Write-Host "Could not retrieve RAM usage: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 3. Disk Usage
    Write-Host "[3] Disk Usage:" -ForegroundColor Yellow
    try {
        Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | ForEach-Object {
            $device = $_.DeviceID
            $totalSpaceGB = [Math]::Round($_.Size / 1GB, 2)
            $freeSpaceGB = [Math]::Round($_.FreeSpace / 1GB, 2)
            $usedSpaceGB = [Math]::Round($totalSpaceGB - $freeSpaceGB, 2)
            $diskUsagePercentage = [Math]::Round(($usedSpaceGB / $totalSpaceGB) * 100, 2)
            Write-Host "  Drive $($device):"
            Write-Host "    Total: $($totalSpaceGB) GB"
            Write-Host "    Free: $($freeSpaceGB) GB"
            Write-Host "    Used: $(<span class="math-inline">usedSpaceGB\) GB \(</span>($diskUsagePercentage)%)"
        }
        Write-Host ""
    }
    catch {
        Write-Host "Could not retrieve Disk usage: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 4. Running Services (Top 10 by CPU/Memory, or just a count)
    Write-Host "[4] Running Services:" -ForegroundColor Yellow
    try {
        $runningServices = Get-Service | Where-Object {$_.Status -eq "Running"}
        Write-Host "Number of Running Services: $($runningServices.Count)"
        Write-Host "Some Running Services (Top 5):"
        $runningServices | Select-Object -First 5 Name, Status | Format-Table -AutoSize
        Write-Host ""
    }
    catch {
        Write-Host "Could not retrieve running services: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 5. Critical Event Logs (Last 24 Hours)
    Write-Host "[5] Critical Event Logs (Last 24 Hours - System & Application):" -ForegroundColor Yellow
    try {
        $criticalEventsSystem = Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=(Get-Date).AddDays(-1)} -ErrorAction SilentlyContinue | Select-Object -First 5 TimeCreated, Id, Message
        $criticalEventsApplication = Get-WinEvent -FilterHashtable @{LogName='Application'; Level=1,2; StartTime=(Get-Date).AddDays(-1)} -ErrorAction SilentlyContinue | Select-Object -First 5 TimeCreated, Id, Message

        if ($criticalEventsSystem) {
            Write-Host "  System Critical Events:"
            $criticalEventsSystem | Format-Table -AutoSize
        } else {
            Write-Host "  No critical System events in the last 24 hours."
        }

        if ($criticalEventsApplication) {
            Write-Host "`n  Application Critical Events:"
            $criticalEventsApplication | Format-Table -AutoSize
        } else {
            Write-Host "  No critical Application events in the last 24 hours."
        }
        Write-Host ""
    }
    catch {
        Write-Host "Could not retrieve critical event logs: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 6. Network Connectivity (Ping Google DNS)
    Write-Host "[6] Network Connectivity (Ping Google DNS 8.8.8.8):" -ForegroundColor Yellow
    try {
        $pingResult = Test-Connection -ComputerName 8.8.8.8 -Count 1 -ErrorAction SilentlyContinue
        if ($pingResult