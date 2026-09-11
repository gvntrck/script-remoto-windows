Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = Get-Content -Raw (Join-Path $PSScriptRoot '..\anydesk.ps1')

if ($source -notmatch 'function Save-AnyDeskInstaller') {
    throw 'Falha: download ainda depende diretamente de Invoke-WebRequest.'
}
if ($source -notmatch 'curl\.exe' -or $source -notmatch '--retry') {
    throw 'Falha: download nao possui transporte alternativo com retry.'
}

Write-Output 'AnyDesk download self-check: ok'
