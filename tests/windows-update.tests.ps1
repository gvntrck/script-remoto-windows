Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\windows-update.ps1')

$regular = [pscustomobject]@{
    Title = 'Windows 11 Quality Update'
    Categories = @([pscustomobject]@{ Name = 'Windows' })
    AutoSelectOnWebSites = $true
}
$driver = [pscustomobject]@{
    Title = 'Example Network Driver'
    Categories = @([pscustomobject]@{ Name = 'Drivers' })
    AutoSelectOnWebSites = $false
}
$preview = [pscustomobject]@{
    Title = 'Windows 11 Preview Update'
    Categories = @([pscustomobject]@{ Name = 'Windows' })
    AutoSelectOnWebSites = $true
}

if ((Get-UpdateKind -Update $regular).IsDriver) { throw 'Falha: update regular classificado como driver.' }
if (-not (Get-UpdateKind -Update $driver).IsDriver) { throw 'Falha: driver nao reconhecido.' }
if (-not (Get-UpdateKind -Update $preview).IsPreview) { throw 'Falha: preview nao reconhecido.' }

$items = @(
    [pscustomobject]@{ Update = $regular; Title = $regular.Title; IsDriver = $false; IsPreview = $false; IsOptional = $false }
    [pscustomobject]@{ Update = $driver; Title = $driver.Title; IsDriver = $true; IsPreview = $false; IsOptional = $true }
    [pscustomobject]@{ Update = $preview; Title = $preview.Title; IsDriver = $false; IsPreview = $true; IsOptional = $false }
)

$defaultSelection = @(Select-WindowsUpdates -Updates $items)
$expandedSelection = @(Select-WindowsUpdates -Updates $items -IncludeDrivers -IncludeOptional)
if ($defaultSelection.Count -ne 1) { throw 'Falha: selecao padrao incorreta.' }
if ($expandedSelection.Count -ne 2) { throw 'Falha: selecao expandida incorreta.' }

Write-Output 'Windows Update self-check: ok'
