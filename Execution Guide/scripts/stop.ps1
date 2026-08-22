#Requires -Version 5.1
<#
.SYNOPSIS
  Stop all local stack services (blockchain, backend, frontend).
.DESCRIPTION
  Always stops the full stack by default. Invokes stack.sh stop, then force-clears
  Windows listeners on the stack ports so orphan Anvil/Java/Next processes are killed.
.EXAMPLE
  .\root\scripts\stop.ps1
  .\root\scripts\stop.ps1 frontend
#>
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$StackArgs
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib/invoke-stack.ps1")

if ($StackArgs -contains '-h' -or $StackArgs -contains '--help' -or $StackArgs -contains 'help') {
    Write-Host @"

Usage: .\root\scripts\stop.ps1 [projects...]

Stops local stack services. With no arguments, stops ALL services.

Projects: all (default), blockchain, backend, frontend

Examples:
  .\root\scripts\stop.ps1
  .\root\scripts\stop.ps1 all
  .\root\scripts\stop.ps1 frontend

"@
    exit 0
}

function Stop-PortListeners {
    param([int[]]$Ports)

    foreach ($port in $Ports) {
        try {
            $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        } catch {
            $conns = $null
        }

        if (-not $conns) {
            # Fallback for older Windows / missing NetTCPConnection
            $lines = netstat -ano 2>$null | Select-String -Pattern ":$port\s+.*LISTENING"
            foreach ($line in $lines) {
                $parts = ($line.ToString() -split '\s+') | Where-Object { $_ }
                $pidText = $parts[-1]
                if ($pidText -match '^\d+$' -and [int]$pidText -gt 0) {
                    Write-Host "[stop] killing PID $pidText on port $port" -ForegroundColor DarkGray
                    & taskkill.exe /PID $pidText /T /F 2>$null | Out-Null
                }
            }
            continue
        }

        $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($procId in $pids) {
            if ($procId -and $procId -gt 0) {
                Write-Host "[stop] killing PID $procId on port $port" -ForegroundColor DarkGray
                & taskkill.exe /PID $procId /T /F 2>$null | Out-Null
            }
        }
    }
}

function Stop-NamedStackProcesses {
    $names = @('anvil')
    foreach ($name in $names) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "[stop] killing $($_.ProcessName) PID $($_.Id)" -ForegroundColor DarkGray
            & taskkill.exe /PID $_.Id /T /F 2>$null | Out-Null
        }
    }
}

# Default: stop everything. Explicit "all" when no project filter is given.
$projects = @()
if ($StackArgs -and $StackArgs.Count -gt 0) {
    $projects = @($StackArgs | Where-Object { $_ -and $_ -notmatch '^-' })
}
if (-not $projects -or $projects.Count -eq 0) {
    $projects = @('all')
}

Write-Host "[stop] stopping stack services: $($projects -join ', ')" -ForegroundColor Cyan

$commandArgs = @('stop') + $projects
$code = 0
try {
    $code = Invoke-StackBash -ScriptsDir $ScriptDir -CommandArgs $commandArgs
} catch {
    Write-Host "[stop] stack.sh stop reported: $($_.Exception.Message)" -ForegroundColor Yellow
    $code = 1
}

# Windows-native sweep — catches orphans (manual anvil, lost pid files, Git Bash pkill gaps).
$stopAll = $projects -contains 'all'
$ports = @()
if ($stopAll -or ($projects -contains 'frontend')) { $ports += 3000 }
if ($stopAll -or ($projects -contains 'backend')) { $ports += 8080 }
if ($stopAll -or ($projects -contains 'blockchain')) { $ports += 8545 }

Write-Host "[stop] clearing listeners on ports: $($ports -join ', ')" -ForegroundColor DarkGray
Stop-PortListeners -Ports $ports

if ($stopAll -or ($projects -contains 'blockchain')) {
    Stop-NamedStackProcesses
}

# Remove stale pid files under .local-runtime
$runtimeDir = Join-Path (Resolve-Path (Join-Path $ScriptDir "../..")).Path ".local-runtime"
foreach ($pidName in @('backend.pid', 'frontend.pid', 'anvil.pid')) {
    $pidPath = Join-Path $runtimeDir $pidName
    if (Test-Path $pidPath) {
        Remove-Item -Force $pidPath -ErrorAction SilentlyContinue
        Write-Host "[stop] removed $pidName" -ForegroundColor DarkGray
    }
}

Write-Host "[stop] all requested services stopped" -ForegroundColor Green
if ($null -eq $code) { $code = 0 }
exit $code
