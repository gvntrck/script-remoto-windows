Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = Get-Content -Raw (Join-Path $PSScriptRoot '..\windows-update.ps1')
$jobPosition = $source.IndexOf('$job = Start-Job')
$statusPosition = $source.IndexOf('Consultando Windows Update')

if ($jobPosition -lt 0) { throw 'Falha: job de busca nao encontrado.' }
if ($statusPosition -lt 0 -or $statusPosition -gt $jobPosition) {
    throw 'Falha: a busca do Windows Update nao possui feedback antes do job bloqueante.'
}

Write-Output 'Windows Update feedback self-check: ok'
