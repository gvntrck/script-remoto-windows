Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\limpeza.ps1')

if (-not (Test-SafeCleanupTarget -Path $env:TEMP)) { throw 'Falha: TEMP valido foi rejeitado.' }
if (Test-SafeCleanupTarget -Path (Get-Location).Path) { throw 'Falha: diretorio arbitrario foi aceito.' }

$items = @(
    [pscustomobject]@{ FullName = 'C:\Temp\arquivo.tmp' }
    [pscustomobject]@{ FullName = 'C:\Temp\pasta\arquivo.tmp' }
)
$ordered = @(Sort-CleanupItemsForRemoval -Items $items)
if ($ordered[0].FullName -ne 'C:\Temp\pasta\arquivo.tmp') { throw 'Falha: itens nao foram ordenados do mais profundo para o mais superficial.' }

Write-Output 'Limpeza self-check: ok'
