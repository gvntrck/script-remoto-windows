[CmdletBinding()]
param()

Set-StrictMode -Version Latest

$script:MaintenanceVersion = '1.7'
$script:RemoteBaseUrl = 'https://projetoalfa.org/win'

function Get-RemoteText {
    param([Parameter(Mandatory)] [string] $RelativePath)

    $uri = '{0}/{1}' -f $script:RemoteBaseUrl.TrimEnd('/'), $RelativePath.TrimStart('/')
    if ($uri -notmatch '^https://') {
        throw 'Somente URLs HTTPS sao permitidas.'
    }

    $originalProtocol = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = $originalProtocol -bor [Net.SecurityProtocolType]::Tls12
        return (Invoke-WebRequest -Uri $uri -UseBasicParsing -ErrorAction Stop).Content
    }
    catch {
        throw "Falha ao carregar ${uri}: $($_.Exception.Message)"
    }
    finally {
        [Net.ServicePointManager]::SecurityProtocol = $originalProtocol
    }
}

if ($PSScriptRoot) {
    . (Join-Path $PSScriptRoot 'lib\Common.ps1')
    . (Join-Path $PSScriptRoot 'debloat.ps1')
    . (Join-Path $PSScriptRoot 'windows-update.ps1')
    . (Join-Path $PSScriptRoot 'anydesk.ps1')
    . (Join-Path $PSScriptRoot 'limpeza.ps1')
    . (Join-Path $PSScriptRoot 'pc-info.ps1')
}
else {
    . ([scriptblock]::Create((Get-RemoteText 'lib/Common.ps1')))
    . ([scriptblock]::Create((Get-RemoteText 'debloat.ps1')))
    . ([scriptblock]::Create((Get-RemoteText 'windows-update.ps1')))
    . ([scriptblock]::Create((Get-RemoteText 'anydesk.ps1')))
    . ([scriptblock]::Create((Get-RemoteText 'limpeza.ps1')))
    . ([scriptblock]::Create((Get-RemoteText 'pc-info.ps1')))
}

function Invoke-DriverBackup {
    if ($env:OS -ne 'Windows_NT') {
        throw 'Este modulo precisa ser executado no Windows.'
    }
    if (-not (Test-IsAdministrator)) {
        throw 'Execute o PowerShell como Administrador para fazer backup ou restaurar drivers.'
    }

    $temporaryPath = $null
    try {
        if ($PSScriptRoot) {
            $scriptPath = Join-Path $PSScriptRoot 'SCRIPT.Drivers.Backup.bat'
        }
        else {
            $temporaryPath = Join-Path ([IO.Path]::GetTempPath()) ("SCRIPT.Drivers.Backup-{0}.bat" -f [Guid]::NewGuid())
            [IO.File]::WriteAllText($temporaryPath, (Get-RemoteText 'SCRIPT.Drivers.Backup.bat'), [Text.Encoding]::ASCII)
            $scriptPath = $temporaryPath
        }

        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            throw "Script de backup nao encontrado: $scriptPath"
        }

        $arguments = @('/d', '/c', ('"{0}"' -f $scriptPath))
        $process = Start-Process -FilePath $env:ComSpec -ArgumentList $arguments -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "O script de backup terminou com codigo $($process.ExitCode)."
        }
    }
    finally {
        if ($temporaryPath -and (Test-Path -LiteralPath $temporaryPath)) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Show-MaintenanceMenu {
    Clear-Host
    Write-Host 'Manutencao Windows 10-11 - gvntrck' -ForegroundColor Cyan
    Write-Host ("v{0}" -f $script:MaintenanceVersion) -ForegroundColor DarkGray
    Write-Host '===================='
    Write-Host '1. Debloat'
    Write-Host '2. Windows Update + Drivers'
    Write-Host '3. Instalar e configurar AnyDesk'
    Write-Host '4. Limpeza de temporarios'
    Write-Host '5. Informacoes do PC'
    Write-Host '6. Backup e restauracao de drivers'
    Write-Host '0. Sair'
}

do {
    Show-MaintenanceMenu
    $option = (Read-Host "`nEscolha").Trim()

    switch ($option) {
        '1' {
            try {
                Invoke-Debloat -Apply
            }
            catch {
                Write-Error $_.Exception.Message
            }
            Read-Host "`nPressione Enter para continuar" | Out-Null
        }
        '2' {
            try {
                Invoke-WindowsUpdate -Install
            }
            catch {
                Write-Error $_.Exception.Message
            }
            Read-Host "`nPressione Enter para continuar" | Out-Null
        }
        '3' {
            try {
                Invoke-AnyDeskSetup
            }
            catch {
                Write-Error $_.Exception.Message
            }
            Read-Host "`nPressione Enter para continuar" | Out-Null
        }
        '4' {
            try {
                Invoke-Cleanup -Apply
            }
            catch {
                Write-Error $_.Exception.Message
            }
            Read-Host "`nPressione Enter para continuar" | Out-Null
        }
        '5' {
            try {
                Show-PCInfo
            }
            catch {
                Write-Error $_.Exception.Message
            }
            Read-Host "`nPressione Enter para continuar" | Out-Null
        }
        '6' {
            try {
                Invoke-DriverBackup
            }
            catch {
                Write-Error $_.Exception.Message
            }
            Read-Host "`nPressione Enter para continuar" | Out-Null
        }
        '0' { return }
        default {
            Write-Warning 'Opcao invalida.'
            Start-Sleep -Seconds 1
        }
    }
} while ($true)
