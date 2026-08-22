# Internal helper — do not run directly. Used by stack.ps1, stop.ps1, clean-projects.ps1.

function Convert-ToGitBashPath {
    param([string]$WindowsPath)
    $full = [System.IO.Path]::GetFullPath($WindowsPath)
    if ($full -match '^([A-Za-z]):\\(.*)$') {
        $drive = $Matches[1].ToLower()
        $rest = ($Matches[2] -replace '\\', '/')
        return "/$drive/$rest"
    }
    return ($full -replace '\\', '/')
}

function Convert-ToWslPath {
    param([string]$WindowsPath)
    $full = [System.IO.Path]::GetFullPath($WindowsPath)
    if ($full -match '^([A-Za-z]):\\(.*)$') {
        $drive = $Matches[1].ToLower()
        $rest = $Matches[2] -replace '\\', '/'
        return "/mnt/$drive/$rest"
    }
    return $full -replace '\\', '/'
}

function Escape-BashSingleQuoted {
    param([string]$Value)
    return $Value -replace "'", "'\''"
}

function Get-GitBashPath {
    $candidates = @(
        "${env:ProgramFiles}\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "${env:LocalAppData}\Programs\Git\bin\bash.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    # Prefer real Git bash over the Windows Store / System32 WSL stub.
    $fromPath = @(where.exe bash 2>$null) |
        Where-Object { $_ -match '\\Git\\' -and $_ -notmatch '\\WindowsApps\\' -and $_ -notmatch '\\System32\\' } |
        Select-Object -First 1
    if ($fromPath -and (Test-Path $fromPath)) {
        return $fromPath
    }

    return $null
}

function Ensure-FoundryOnPath {
    $foundryBin = Join-Path $env:USERPROFILE ".foundry\bin"
    if (Test-Path $foundryBin) {
        $env:PATH = "$foundryBin;$env:PATH"
    }
}

function Ensure-JavaOnPath {
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
        $env:PATH = "$(Join-Path $env:JAVA_HOME 'bin');$env:PATH"
        return
    }

    $jdkRoot = Join-Path $env:USERPROFILE ".jdks"
    if (Test-Path $jdkRoot) {
        $latest = Get-ChildItem $jdkRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if ($latest) {
            $bin = Join-Path $latest.FullName "bin"
            if (Test-Path (Join-Path $bin "java.exe")) {
                $env:JAVA_HOME = $latest.FullName
                $env:PATH = "$bin;$env:PATH"
            }
        }
    }
}

function Invoke-StackBash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptsDir,
        [Parameter(Mandatory = $false)]
        [string[]]$CommandArgs = @()
    )

    $StackSh = Join-Path $ScriptsDir "stack.sh"
    if (-not (Test-Path $StackSh)) {
        Write-Error "stack.sh not found at $StackSh"
        exit 1
    }

    Ensure-FoundryOnPath
    Ensure-JavaOnPath

    $WorkspaceRoot = (Resolve-Path (Join-Path $ScriptsDir "../..")).Path
    $gitBash = Get-GitBashPath

    if ($gitBash) {
        # Ensure child bash sees Foundry + Maven/Node from the Windows PATH.
        $env:MSYS2_ARG_CONV_EXCL = "*"
        $bashRoot = Convert-ToGitBashPath $WorkspaceRoot
        Write-Host "[stack] using Git Bash: $gitBash" -ForegroundColor DarkGray
        Write-Host "[stack] workspace: $bashRoot" -ForegroundColor DarkGray

        # Invoke the script as a file (not bash -lc "...") so MSYS keeps a real console
        # stream and PowerShell shows progress logs.
        $prev = Get-Location
        try {
            Set-Location -LiteralPath $WorkspaceRoot
            & $gitBash --noprofile --norc "./root/scripts/stack.sh" @CommandArgs
            return $LASTEXITCODE
        }
        finally {
            Set-Location -LiteralPath $prev.Path
        }
    }

    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($wsl) {
        $wslRoot = Convert-ToWslPath $WorkspaceRoot
        $argList = ($CommandArgs | ForEach-Object { "'" + (Escape-BashSingleQuoted $_) + "'" }) -join ' '
        $command = "cd '$wslRoot' && bash root/scripts/stack.sh"
        if ($argList) {
            $command += " $argList"
        }
        Write-Host "[stack] using WSL" -ForegroundColor DarkGray
        & wsl.exe bash -lc $command
        return $LASTEXITCODE
    }

    Write-Error @"
bash not found. Install one of:
  - Git for Windows (recommended): https://git-scm.com/download/win
  - WSL: wsl --install
Also ensure Foundry is installed: https://getfoundry.sh
"@
    exit 1
}
