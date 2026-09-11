Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\pc-info.ps1')

function Find-AnyDeskExecutable { return 'C:\Program Files\AnyDesk\AnyDesk.exe' }
function Get-AnyDeskValue { return '123456789' }

function Get-PCInfoCim {
    param([string] $ClassName, [string] $Filter)

    switch ($ClassName) {
        'Win32_ComputerSystem' { return @([pscustomobject]@{ Name = 'PC-TESTE'; PartOfDomain = $true; Domain = 'ALFA.LOCAL' }) }
        'Win32_OperatingSystem' { return @([pscustomobject]@{ Caption = 'Microsoft Windows 11 Pro'; BuildNumber = '26200'; TotalVisibleMemorySize = 16777216 }) }
        'Win32_Processor' { return @([pscustomobject]@{ Name = 'CPU de teste' }) }
        'Win32_BIOS' { return @([pscustomobject]@{ SerialNumber = 'SERIAL-TESTE' }) }
        'Win32_VideoController' { return @([pscustomobject]@{ Name = 'GPU de teste' }) }
        'Win32_LogicalDisk' { return @([pscustomobject]@{ DeviceID = 'C:'; FreeSpace = 50GB; Size = 100GB }) }
        'Win32_UserAccount' { return @([pscustomobject]@{ Name = 'Administrador' }, [pscustomobject]@{ Name = 'Suporte' }) }
        default { return @() }
    }
}

$info = Get-PCInfoSnapshot
if ($info.Hostname -ne 'PC-TESTE') { throw 'Falha: hostname nao foi coletado.' }
if ($info.Domain -ne 'ALFA.LOCAL') { throw 'Falha: dominio nao foi coletado.' }
if ($info.LocalUsers.Count -ne 2) { throw 'Falha: usuarios locais nao foram coletados.' }
if ($info.Disks -notmatch 'C:') { throw 'Falha: disco nao foi formatado.' }
if ($info.AnyDeskId -ne '123 456 789') { throw 'Falha: ID do AnyDesk nao foi coletado ou formatado.' }
if ((Format-PCInfoAnyDeskId 'n/d') -ne 'n/d') { throw 'Falha: ID indisponivel foi alterado.' }
if ((Format-PCInfoSize 1GB) -notmatch '1,0|1\.0') { throw 'Falha: tamanho nao foi formatado.' }

Write-Output 'PC info self-check: ok'
