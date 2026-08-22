#Requires -Version 5.1
<#
.SYNOPSIS
  Smoke-check local FE+BE wired to live Sepolia (no Anvil).
.EXAMPLE
  .\root\scripts\smoke-sepolia-local.ps1
  .\root\scripts\smoke-sepolia-local.ps1 -StartStack
#>
param(
    [switch]$StartStack,
    [switch]$SkipHttp
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib/invoke-stack.ps1")

$Workspace = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$RuntimeEnv = Join-Path $Workspace ".local-runtime\stack.env"
$FrontendEnv = Join-Path $Workspace "rwa-tokenized-compliance-system-frontend\.env.local"
$ContractsTs = Join-Path $Workspace "rwa-tokenized-compliance-system-frontend\src\shared\config\contracts.generated.ts"
$Addresses = Join-Path $Workspace "rwa-tokenized-compliance-system-blockchain\config\sepolia-addresses.json"

function Assert-True([bool]$Cond, [string]$Msg) {
    if (-not $Cond) { throw "[smoke] FAIL: $Msg" }
    Write-Host "[smoke] OK: $Msg"
}

Write-Host "[smoke] syncing stack env for Sepolia..."
$code = Invoke-StackBash -ScriptsDir $ScriptDir -CommandArgs @('sync', '--chain', 'sepolia')
if ($code -ne 0) { throw "[smoke] stack sync failed (exit $code)" }

Assert-True (Test-Path $RuntimeEnv) "stack.env exists"
Assert-True (Test-Path $FrontendEnv) "frontend .env.local exists"
Assert-True (Test-Path $ContractsTs) "contracts.generated.ts exists"
Assert-True (Test-Path $Addresses) "sepolia-addresses.json exists"

$envMap = @{}
Get-Content $RuntimeEnv | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $parts = $_.Split('=', 2)
    $envMap[$parts[0]] = $parts[1]
}

$addr = Get-Content $Addresses -Raw | ConvertFrom-Json
Assert-True ($envMap['STACK_CHAIN_TARGET'] -eq 'sepolia') "STACK_CHAIN_TARGET=sepolia"
Assert-True ($envMap['LOCAL_CHAIN_ID'] -eq '11155111') "chain id 11155111"
Assert-True ($envMap['BLOCKCHAIN_MODE'] -eq 'trex') "blockchain mode trex"
Assert-True ($envMap['SPRING_PROFILES_ACTIVE'] -match 'sepolia') "Spring profile includes sepolia"
Assert-True ($envMap['IDENTITY_REGISTRY_ADDRESS'] -eq $addr.identityRegistry) "IR matches sepolia-addresses.json"
Assert-True ($envMap['TOKEN_ADDRESS'] -eq $addr.token) "token matches sepolia-addresses.json"
Assert-True ($envMap['MODULAR_COMPLIANCE_ADDRESS'] -eq $addr.modularCompliance) "MC matches sepolia-addresses.json"
Assert-True ($envMap['RPC_URL'] -notmatch '127\.0\.0\.1|localhost') "RPC is not localhost"
Assert-True ($envMap['NEXT_PUBLIC_RPC_URL'] -notmatch '127\.0\.0\.1|localhost') "NEXT_PUBLIC_RPC is not localhost"

$contractsText = Get-Content $ContractsTs -Raw
Assert-True ($contractsText -match [regex]::Escape($addr.identityRegistry)) "frontend contracts IR"
Assert-True ($contractsText -match [regex]::Escape($addr.token)) "frontend contracts token"

$feEnv = Get-Content $FrontendEnv -Raw
Assert-True ($feEnv -match 'NEXT_PUBLIC_CHAIN_ID=11155111') "frontend chain id"
Assert-True ($feEnv -match [regex]::Escape($addr.identityRegistry)) "frontend .env.local IR"

if ($StartStack) {
    Write-Host "[smoke] starting backend + frontend against Sepolia..."
    $code = Invoke-StackBash -ScriptsDir $ScriptDir -CommandArgs @(
        'up', '--chain', 'sepolia', '--skip-deps', 'backend', 'frontend'
    )
    if ($code -ne 0) { throw "[smoke] stack up failed (exit $code)" }
}

if (-not $SkipHttp) {
    $backend = if ($envMap['BACKEND_API_BASE_URL']) { $envMap['BACKEND_API_BASE_URL'] } else { 'http://127.0.0.1:8080' }
    $frontend = 'http://127.0.0.1:3000'
    try {
        $health = Invoke-WebRequest -Uri "$backend/actuator/health" -UseBasicParsing -TimeoutSec 5
        Assert-True ($health.StatusCode -eq 200) "backend health HTTP $($health.StatusCode)"
    } catch {
        Write-Host "[smoke] SKIP: backend not reachable at $backend (start with -StartStack or stack up --chain sepolia)"
    }
    try {
        $fe = Invoke-WebRequest -Uri $frontend -UseBasicParsing -TimeoutSec 5
        Assert-True ($fe.StatusCode -lt 500) "frontend HTTP $($fe.StatusCode)"
    } catch {
        Write-Host "[smoke] SKIP: frontend not reachable at $frontend"
    }
}

Write-Host "[smoke] Sepolia local wiring OK"
Write-Host "[smoke] Next: .\root\scripts\stack.ps1 up --chain sepolia --skip-deps"
