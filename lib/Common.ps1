Set-StrictMode -Version Latest

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-MaintenanceLog {
    param(
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')] [string] $Level = 'INFO'
    )

    $logDirectory = Join-Path $env:ProgramData 'ManutencaoWindows\logs'
    try {
        New-Item -Path $logDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        $logPath = Join-Path $logDirectory ("{0:yyyy-MM-dd}.log" -f (Get-Date))
        Add-Content -Path $logPath -Value ("{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}" -f (Get-Date), $Level, $Message) -ErrorAction Stop
    }
    catch {
        # Log failure must not hide the actual maintenance result.
    }
}

function Read-YesNo {
    param([Parameter(Mandatory)] [string] $Prompt)

    do {
        $answer = (Read-Host "$Prompt [s/N]").Trim().ToLowerInvariant()
    } while ($answer -notin @('', 's', 'sim', 'n', 'nao'))

    return $answer -in @('s', 'sim')
}
