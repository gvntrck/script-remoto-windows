[CmdletBinding()]
param()

Set-StrictMode -Version Latest

if ($PSScriptRoot) {
    $commonPath = Join-Path $PSScriptRoot 'lib\Common.ps1'
    if (Test-Path $commonPath) {
        . $commonPath
    }
}

function Get-BuiltinAdministrator {
    Get-LocalUser -ErrorAction Stop |
        Where-Object { $_.SID.Value -match '-500$' } |
        Select-Object -First 1
}

function ConvertTo-PlainText {
    param([Parameter(Mandatory)] [SecureString] $Secure)

    return [Net.NetworkCredential]::new('x', $Secure).Password
}

function Invoke-LocalAdminSetup {
    if ($env:OS -ne 'Windows_NT') {
        throw 'Este modulo precisa ser executado no Windows.'
    }
    if (-not (Test-IsAdministrator)) {
        throw 'Execute o PowerShell como Administrador para gerenciar a conta Administrador local.'
    }

    $account = Get-BuiltinAdministrator
    if (-not $account) {
        throw 'Conta interna de administrador (SID-500) nao encontrada.'
    }

    if ($account.Enabled) {
        Write-Host ("Conta '{0}' ja esta ativa." -f $account.Name) -ForegroundColor Yellow
    }
    else {
        $account | Enable-LocalUser -ErrorAction Stop
        Write-Host ("Conta '{0}' ativada." -f $account.Name) -ForegroundColor Green
    }

    $password = $null
    while (-not $password) {
        $candidate = Read-Host 'Nova senha' -AsSecureString
        $plain = ConvertTo-PlainText $candidate
        if ([string]::IsNullOrEmpty($plain)) {
            Write-Warning 'A senha nao pode ser vazia.'
            continue
        }
        if ($plain -cne (ConvertTo-PlainText (Read-Host 'Confirme a senha' -AsSecureString))) {
            Write-Warning 'As senhas nao conferem. Tente novamente.'
            continue
        }
        $password = $candidate
    }

    $account | Set-LocalUser -Password $password -ErrorAction Stop
    Write-MaintenanceLog ("Conta '{0}' ativa e senha redefinida." -f $account.Name)
    Write-Host 'Senha definida com sucesso.' -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-LocalAdminSetup
}
