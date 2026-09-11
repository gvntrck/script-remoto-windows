[CmdletBinding()]
param()

Set-StrictMode -Version Latest

if ($PSScriptRoot -and -not (Get-Command Find-AnyDeskExecutable -CommandType Function -ErrorAction SilentlyContinue)) {
    $anyDeskPath = Join-Path $PSScriptRoot 'anydesk.ps1'
    if (Test-Path -LiteralPath $anyDeskPath) { . $anyDeskPath }
}

function Get-PCInfoCim {
    param(
        [Parameter(Mandatory)] [string] $ClassName,
        [string] $Filter
    )

    $arguments = @{ ClassName = $ClassName; ErrorAction = 'Stop' }
    if ($Filter) { $arguments.Filter = $Filter }

    try {
        if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
            return @(Get-CimInstance @arguments)
        }
    }
    catch { }

    try {
        if (Get-Command Get-WmiObject -ErrorAction SilentlyContinue) {
            if ($Filter) {
                return @(Get-WmiObject -Class $ClassName -Filter $Filter -ErrorAction Stop)
            }
            return @(Get-WmiObject -Class $ClassName -ErrorAction Stop)
        }
    }
    catch { }

    return @()
}

function Get-PCInfoProperty {
    param(
        [AllowNull()] $InputObject,
        [Parameter(Mandatory)] [string] $Name,
        [object] $Default = 'n/d'
    )

    if ($null -eq $InputObject) { return $Default }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value -or [string]::IsNullOrWhiteSpace([string] $property.Value)) {
        return $Default
    }
    return $property.Value
}

function Format-PCInfoSize {
    param([AllowNull()] [Nullable[double]] $Bytes)

    if ($null -eq $Bytes -or $Bytes -lt 0) { return 'n/d' }
    return '{0:N1} GB' -f ($Bytes / 1GB)
}

function Get-PCInfoAnyDeskId {
    if (-not (Get-Command Find-AnyDeskExecutable -CommandType Function -ErrorAction SilentlyContinue)) {
        return 'n/d'
    }

    try {
        $executable = Find-AnyDeskExecutable
        if (-not $executable) { return 'n/d' }
        $id = Get-AnyDeskValue -Executable $executable -Argument '--get-id'
        if ($id -and $id -ne 'indisponivel') { return $id }
    }
    catch { }

    return 'n/d'
}

function Format-PCInfoAnyDeskId {
    param([AllowNull()] [string] $Id)

    if ([string]::IsNullOrWhiteSpace($Id) -or $Id -eq 'n/d') { return 'n/d' }
    if ($Id -notmatch '^\d+$') { return $Id }
    return [regex]::Replace($Id, '(?<=\d)(?=(\d{3})+$)', ' ')
}

function Get-PCInfoSnapshot {
    $system = Get-PCInfoCim -ClassName 'Win32_ComputerSystem' | Select-Object -First 1
    $os = Get-PCInfoCim -ClassName 'Win32_OperatingSystem' | Select-Object -First 1
    $processor = Get-PCInfoCim -ClassName 'Win32_Processor' | Select-Object -First 1
    $bios = Get-PCInfoCim -ClassName 'Win32_BIOS' | Select-Object -First 1
    $gpu = @(Get-PCInfoCim -ClassName 'Win32_VideoController')
    $disks = @(Get-PCInfoCim -ClassName 'Win32_LogicalDisk' -Filter "DriveType = 3")
    $users = @(Get-PCInfoCim -ClassName 'Win32_UserAccount' -Filter 'LocalAccount = True' | Sort-Object Name)

    $memoryBytes = $null
    $memoryKb = Get-PCInfoProperty -InputObject $os -Name 'TotalVisibleMemorySize' -Default $null
    if ($null -ne $memoryKb -and $memoryKb -isnot [string]) {
        try { $memoryBytes = [double] $memoryKb * 1KB } catch { }
    }

    $diskSummary = @($disks | ForEach-Object {
        $device = Get-PCInfoProperty -InputObject $_ -Name 'DeviceID'
        $free = Get-PCInfoProperty -InputObject $_ -Name 'FreeSpace' -Default $null
        $size = Get-PCInfoProperty -InputObject $_ -Name 'Size' -Default $null
        if ($null -ne $free -and $null -ne $size) {
            '{0}: {1} livres / {2}' -f $device, (Format-PCInfoSize ([double] $free)), (Format-PCInfoSize ([double] $size))
        }
    })

    [pscustomobject]@{
        Hostname = Get-PCInfoProperty -InputObject $system -Name 'Name' -Default $env:COMPUTERNAME
        Domain = if ([bool] (Get-PCInfoProperty -InputObject $system -Name 'PartOfDomain' -Default $false)) {
            Get-PCInfoProperty -InputObject $system -Name 'Domain'
        }
        else {
            'WORKGROUP'
        }
        CurrentUser = if ($env:USERDOMAIN) { '{0}\{1}' -f $env:USERDOMAIN, $env:USERNAME } else { $env:USERNAME }
        LocalUsers = @($users | ForEach-Object { Get-PCInfoProperty -InputObject $_ -Name 'Name' })
        OperatingSystem = '{0} | build {1}' -f (Get-PCInfoProperty -InputObject $os -Name 'Caption'), (Get-PCInfoProperty -InputObject $os -Name 'BuildNumber')
        Processor = Get-PCInfoProperty -InputObject $processor -Name 'Name'
        Memory = Format-PCInfoSize $memoryBytes
        Disks = if ($diskSummary.Count -gt 0) { $diskSummary -join '; ' } else { 'n/d' }
        Graphics = if ($gpu.Count -gt 0) { (@($gpu | ForEach-Object { Get-PCInfoProperty -InputObject $_ -Name 'Name' }) -join '; ') } else { 'n/d' }
        Serial = Get-PCInfoProperty -InputObject $bios -Name 'SerialNumber'
        AnyDeskId = Format-PCInfoAnyDeskId (Get-PCInfoAnyDeskId)
    }
}

function Show-PCInfo {
    Write-Host 'Coletando informacoes do computador...' -ForegroundColor Cyan
    $info = Get-PCInfoSnapshot
    Write-Host ''
    Write-Host '=== Informacoes do PC ===' -ForegroundColor Cyan
    Write-Host ('Hostname      : {0}' -f $info.Hostname)
    Write-Host ('Dominio/grupo : {0}' -f $info.Domain)
    Write-Host ('Usuario atual : {0}' -f $info.CurrentUser)
    Write-Host ('Usuarios loc. : {0}' -f ($(if ($info.LocalUsers.Count -gt 0) { $info.LocalUsers -join ', ' } else { 'n/d' })))
    Write-Host ('Sistema       : {0}' -f $info.OperatingSystem)
    Write-Host ('CPU           : {0}' -f $info.Processor)
    Write-Host ('RAM           : {0}' -f $info.Memory)
    Write-Host ('Discos        : {0}' -f $info.Disks)
    Write-Host ('GPU           : {0}' -f $info.Graphics)
    Write-Host ('Serial        : {0}' -f $info.Serial)
    Write-Host ('AnyDesk ID    : {0}' -f $info.AnyDeskId)
}

if ($MyInvocation.InvocationName -ne '.') {
    Show-PCInfo
}
