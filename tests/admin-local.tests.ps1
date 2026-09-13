Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\admin-local.ps1')

function Get-LocalUser {
    return @(
        [pscustomobject]@{ Name = 'Convidado'; Enabled = $false; SID = [Security.Principal.SecurityIdentifier]::new('S-1-5-21-100-200-300-501') }
        [pscustomobject]@{ Name = 'Administrador'; Enabled = $false; SID = [Security.Principal.SecurityIdentifier]::new('S-1-5-21-100-200-300-500') }
        [pscustomobject]@{ Name = 'Suporte'; Enabled = $true; SID = [Security.Principal.SecurityIdentifier]::new('S-1-5-21-100-200-300-1001') }
    )
}

$account = Get-BuiltinAdministrator
if (-not $account -or $account.Name -ne 'Administrador') {
    throw 'Falha: conta interna SID-500 nao foi localizada.'
}

$secure = ConvertTo-SecureString 'SenhaForte123' -AsPlainText -Force
if ((ConvertTo-PlainText $secure) -cne 'SenhaForte123') {
    throw 'Falha: conversao de SecureString divergiu.'
}

Write-Output 'Admin local self-check: ok'
