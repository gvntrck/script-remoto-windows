Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$menu = Get-Content -Raw (Join-Path $PSScriptRoot '..\menu.ps1')
$backup = Get-Content -Raw (Join-Path $PSScriptRoot '..\SCRIPT.Drivers.Backup.bat')

if ($menu -notmatch "Write-Host '6\. Backup e restauracao de drivers'") {
    throw 'Falha: opcao 6 nao foi adicionada ao menu principal.'
}
if ($menu -notmatch 'Invoke-DriverBackup') {
    throw 'Falha: opcao 6 nao chama o lancador de backup.'
}
if ($backup -notmatch '(?m)^@echo off') {
    throw 'Falha: script integral de backup nao foi encontrado.'
}
if ($backup -notmatch '(?m)^set /p opcao=') {
    throw 'Falha: menu proprio do script de backup nao foi preservado.'
}
if ($backup -notmatch '(?m)pnputil -i -a') {
    throw 'Falha: fallback para versoes antigas do Windows 10 nao foi preservado.'
}

Write-Output 'Driver backup self-check: ok'
