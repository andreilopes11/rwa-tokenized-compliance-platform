#Requires -Version 5.1
<#
.SYNOPSIS
  Remove temporary build artifacts from backend, blockchain, and frontend.
.EXAMPLE
  .\root\scripts\clean-projects.ps1
  .\root\scripts\clean-projects.ps1 -Full
  .\root\scripts\clean-projects.ps1 -DryRun
  .\root\scripts\clean-projects.ps1 -Backend
.PARAMETER Full
  Also remove node_modules, .local-runtime, and blockchain deployments.
.PARAMETER DryRun
  Show what would be removed without deleting.
.PARAMETER Deps
  Also remove node_modules (blockchain + frontend).
.PARAMETER Runtime
  Also remove workspace .local-runtime/ (logs, pid files).
.PARAMETER Deployments
  Also remove blockchain deployments/ (requires redeploy).
.PARAMETER Backend
  Clean backend only (target/).
.PARAMETER Blockchain
  Clean blockchain only (cache/, out/, broadcast/, etc.).
.PARAMETER Frontend
  Clean frontend only (.next/, .cache/, etc.).
#>
[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$DryRun,
    [switch]$Deps,
    [switch]$Runtime,
    [switch]$Deployments,
    [switch]$Backend,
    [switch]$Blockchain,
    [switch]$Frontend
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib/invoke-stack.ps1")

$bashArgs = @('clean')

if ($Full) {
    $bashArgs += '--full'
}
if ($DryRun) {
    $bashArgs += '--dry-run'
}
if ($Deps) {
    $bashArgs += '--deps'
}
if ($Runtime) {
    $bashArgs += '--runtime'
}
if ($Deployments) {
    $bashArgs += '--deployments'
}
if ($Backend) {
    $bashArgs += '--backend'
}
if ($Blockchain) {
    $bashArgs += '--blockchain'
}
if ($Frontend) {
    $bashArgs += '--frontend'
}

$code = Invoke-StackBash -ScriptsDir $ScriptDir -CommandArgs $bashArgs
exit $code
