#Requires -Version 5.1
<#
.SYNOPSIS
  Start and manage the local stack (blockchain, backend, frontend).
.EXAMPLE
  .\root\scripts\stack.ps1
  .\root\scripts\stack.ps1 up
  .\root\scripts\stack.ps1 sync --chain sepolia
  .\root\scripts\stack.ps1 up --chain sepolia --skip-deps
  .\root\scripts\stack.ps1 up --update
  .\root\scripts\stack.ps1 deps --update
  .\root\scripts\stack.ps1 cache
  .\root\scripts\stack.ps1 start --skip-deps
  .\root\scripts\stack.ps1 status
.NOTES
  Default (no args): full bring-up (cache/deps + start all three services).
  Use --chain sepolia for FE+BE against live Sepolia (no Anvil).
  For stop only use stop.ps1. For cleanup use clean-projects.ps1.
#>
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$StackArgs
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib/invoke-stack.ps1")

function Show-StackHelp {
    Write-Host @"

Usage: .\root\scripts\stack.ps1 [command] [options] [projects...]

Default (no args): up — install/update deps + start blockchain + backend + frontend.

Commands:
  up      [projects...]   Recommended: tooling check → deps/cache → start all
  start   [projects...]   Start services (runs deps unless --skip-deps)
  stop    [projects...]   Stop services (prefer .\root\scripts\stop.ps1)
  deps                    Install dependencies + forge build
  cache                   Update forge/npm/Maven caches (no start)
  sync                    Sync local env from deployment / Sepolia addresses
  verify                  Run all project tests
  check                   Verify required tooling
  status                  Show running state

Options:
  --chain sepolia|anvil  Chain target (default anvil). sepolia skips Anvil
  --update / --force     Force npm reinstall + Maven -U (up / deps / cache)
  --skip-deps            Skip dependency install (start / up)
  --no-stop              Do not stop before start

Projects: all (default), blockchain, backend, frontend

Examples:
  .\root\scripts\stack.ps1
  .\root\scripts\stack.ps1 sync --chain sepolia
  .\root\scripts\stack.ps1 up --chain sepolia --skip-deps
  .\root\scripts\stack.ps1 up --update
  .\root\scripts\stack.ps1 deps --update
  .\root\scripts\stack.ps1 cache
  .\root\scripts\stack.ps1 start --skip-deps
  .\root\scripts\stack.ps1 status

Stop:    .\root\scripts\stop.ps1
Cleanup: .\root\scripts\clean-projects.ps1
Smoke:   .\root\scripts\smoke-sepolia-local.ps1

"@
}

if ($StackArgs -and $StackArgs.Count -gt 0 -and ($StackArgs[0] -in @('-h', '--help', 'help'))) {
    Show-StackHelp
    exit 0
}

if ($StackArgs -and $StackArgs.Count -gt 0 -and $StackArgs[0] -eq 'clean') {
    Write-Host "Use .\root\scripts\clean-projects.ps1 for cleanup." -ForegroundColor Yellow
    exit 1
}

# Default: full up (deps + start). Previously this only called "start".
if (-not $StackArgs -or $StackArgs.Count -eq 0) {
    $code = Invoke-StackBash -ScriptsDir $ScriptDir -CommandArgs @('up')
    exit $code
}

if ($StackArgs[0] -eq 'stop') {
    Write-Host "Tip: use .\root\scripts\stop.ps1 to stop services." -ForegroundColor Yellow
}

$code = Invoke-StackBash -ScriptsDir $ScriptDir -CommandArgs $StackArgs
exit $code
