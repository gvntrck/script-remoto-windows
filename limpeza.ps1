[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [switch] $Apply
)

Set-StrictMode -Version Latest

if ($PSScriptRoot) {
    $commonPath = Join-Path $PSScriptRoot 'lib\Common.ps1'
    if (Test-Path $commonPath) {
        . $commonPath
    }
}

function Get-CleanupTargetPaths {
    $paths = @(
        $env:TEMP
        if ($env:WINDIR) { Join-Path $env:WINDIR 'Temp' }
    )

    return @($paths |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
        ForEach-Object { [IO.Path]::GetFullPath($_).TrimEnd('\') } |
        Select-Object -Unique)
}

function Test-SafeCleanupTarget {
    param([Parameter(Mandatory)] [string] $Path)

    try {
        $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd('\')
        return (Split-Path -Leaf $fullPath) -eq 'Temp' -and (Test-Path -LiteralPath $fullPath -PathType Container)
    }
    catch {
        return $false
    }
}

function Get-CleanupInventory {
    $items = foreach ($target in @(Get-CleanupTargetPaths | Where-Object { Test-SafeCleanupTarget $_ })) {
        try {
            Get-ChildItem -LiteralPath $target -Force -Recurse -ErrorAction SilentlyContinue |
                Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |
                ForEach-Object {
                    [pscustomobject]@{
                        Target = $target
                        FullName = $_.FullName
                        IsDirectory = [bool] $_.PSIsContainer
                        Length = if ($_.PSIsContainer) { [int64] 0 } else { [int64] $_.Length }
                    }
                }
        }
        catch {
            Write-Warning ("Falha ao ler {0}: {1}" -f $target, $_.Exception.Message)
        }
    }

    return @($items)
}

function Sort-CleanupItemsForRemoval {
    param([Parameter(Mandatory)] [object[]] $Items)

    return @($Items | Sort-Object @{ Expression = { $_.FullName.Length }; Descending = $true })
}

function Invoke-Cleanup {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param([switch] $Apply)

    $inventory = @(Get-CleanupInventory)
    $fileCount = @($inventory | Where-Object { -not $_.IsDirectory }).Count
    $totalBytes = [int64] (($inventory | Measure-Object -Property Length -Sum).Sum)
    if ($null -eq $totalBytes) { $totalBytes = 0 }

    Write-Host ("Temporarios encontrados: {0} item(ns), {1} arquivo(s), {2:N1} MB." -f $inventory.Count, $fileCount, ($totalBytes / 1MB)) -ForegroundColor Cyan

    if ($inventory.Count -eq 0) {
        Write-Host 'Nenhum temporario removivel encontrado.' -ForegroundColor Green
        return
    }

    if (-not $Apply) {
        Write-Host 'Previa concluida. Nada foi alterado. Use -Apply para remover apos revisar.' -ForegroundColor Cyan
        return
    }

    if (-not (Test-IsAdministrator)) {
        throw 'Execute o PowerShell como Administrador para limpar temporarios do sistema.'
    }

    if (-not (Read-YesNo 'Remover os temporarios encontrados?')) {
        Write-Host 'Operacao cancelada.' -ForegroundColor Yellow
        return
    }

    $orderedItems = @(Sort-CleanupItemsForRemoval -Items $inventory)
    $removed = 0
    $failed = 0
    for ($index = 0; $index -lt $orderedItems.Count; $index++) {
        $item = $orderedItems[$index]
        Write-Progress -Activity 'Limpeza de temporarios' -Status ("{0}/{1}" -f ($index + 1), $orderedItems.Count) -PercentComplete ((($index + 1) / $orderedItems.Count) * 100)
        try {
            if ($PSCmdlet.ShouldProcess($item.FullName, 'Remover')) {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                $removed++
            }
        }
        catch {
            $failed++
        }
    }
    Write-Progress -Activity 'Limpeza de temporarios' -Completed

    Write-MaintenanceLog "Limpeza concluida: removidos=$removed falhas=$failed bytes=$totalBytes"
    Write-Host ("Concluido: {0} removido(s), {1} falha(s), ate {2:N1} MB processados." -f $removed, $failed, ($totalBytes / 1MB)) -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Cleanup -Apply:$Apply
}
