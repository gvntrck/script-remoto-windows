[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [switch] $Install,
    [switch] $IncludeDrivers,
    [switch] $IncludeOptional,
    [switch] $Reboot
)

Set-StrictMode -Version Latest

if ($PSScriptRoot) {
    $commonPath = Join-Path $PSScriptRoot 'lib\Common.ps1'
    if (Test-Path $commonPath) {
        . $commonPath
    }
}

function Get-UpdateKind {
    param([Parameter(Mandatory)] $Update)

    $title = [string] $Update.Title
    $categories = @($Update.Categories | ForEach-Object {
        if ($_.PSObject.Properties.Name -contains 'Name') { [string] $_.Name } else { [string] $_ }
    })
    $isDriver = ($categories -match '(?i)driver').Count -gt 0 -or $title -match '(?i)\bdriver\b'
    $isPreview = $title -match '(?i)\bpreview\b'

    try {
        $isOptional = -not [bool] $Update.AutoSelectOnWebSites
    }
    catch {
        $isOptional = $isPreview
    }

    [pscustomobject]@{
        IsDriver = $isDriver
        IsPreview = $isPreview
        IsOptional = $isOptional
    }
}

function Get-WindowsUpdateInventory {
    if ($env:OS -ne 'Windows_NT') {
        throw 'Este modulo precisa ser executado no Windows.'
    }

    $spinner = @('|', '/', '-', '\')
    $spinnerIndex = 0
    $started = Get-Date
    Write-Host 'Consultando Windows Update...' -ForegroundColor Cyan

    $job = Start-Job -ScriptBlock {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $result = $searcher.Search('IsInstalled=0 and IsHidden=0')

        foreach ($update in @($result.Updates)) {
            $autoSelect = $true
            try { $autoSelect = [bool] $update.AutoSelectOnWebSites } catch { }
            [pscustomobject]@{
                Title = [string] $update.Title
                UpdateId = [string] $update.Identity.UpdateID
                Categories = @($update.Categories | ForEach-Object { [string] $_.Name })
                AutoSelectOnWebSites = $autoSelect
            }
        }
    }

    try {
        while ((Get-Job -Id $job.Id).State -in @('NotStarted', 'Running')) {
            $seconds = [int] ((Get-Date) - $started).TotalSeconds
            Write-Progress -Activity 'Windows Update' -Status ("Consultando catalogo... {0}s" -f $seconds)
            Write-Host ("`r{0} Consultando catalogo do Windows Update... {1}s" -f $spinner[$spinnerIndex], $seconds) -NoNewline
            $spinnerIndex = ($spinnerIndex + 1) % $spinner.Count
            Start-Sleep -Milliseconds 350
        }

        $job = Get-Job -Id $job.Id
        if ($job.State -eq 'Failed') {
            throw $job.ChildJobs[0].JobStateInfo.Reason
        }

        $rawUpdates = @(Receive-Job -Job $job -ErrorAction Stop)
        Write-Progress -Activity 'Windows Update' -Completed
        Write-Host "`rConsulta concluida.                                             "
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }

    return @($rawUpdates | ForEach-Object {
        $kind = Get-UpdateKind -Update $_
        [pscustomobject]@{
            Update = $null
            UpdateId = $_.UpdateId
            Title = $_.Title
            IsDriver = $kind.IsDriver
            IsPreview = $kind.IsPreview
            IsOptional = $kind.IsOptional
        }
    })
}

function Select-WindowsUpdates {
    param(
        [Parameter(Mandatory)] [object[]] $Updates,
        [switch] $IncludeDrivers,
        [switch] $IncludeOptional
    )

    return @($Updates | Where-Object {
        if ($_.IsPreview) {
            $false
        }
        elseif ($_.IsDriver) {
            [bool] $IncludeDrivers
        }
        else {
            [bool] $IncludeOptional -or -not $_.IsOptional
        }
    })
}

function Invoke-WindowsUpdateInstall {
    param([Parameter(Mandatory)] [string[]] $UpdateIds)

    $job = Start-Job -ArgumentList (,$UpdateIds) -ScriptBlock {
        param([string[]] $RequestedIds)

        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $result = $searcher.Search('IsInstalled=0 and IsHidden=0')
        $updates = @($result.Updates | Where-Object { $RequestedIds -contains [string] $_.Identity.UpdateID })

        if ($updates.Count -ne $RequestedIds.Count) {
            throw 'Uma ou mais atualizacoes selecionadas mudaram antes da instalacao.'
        }

        $collection = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $updates) {
            if (-not $update.EulaAccepted) { $update.AcceptEula() }
            [void] $collection.Add($update)
        }

        $downloader = $session.CreateUpdateDownloader()
        $downloader.Updates = $collection
        $downloadResult = $downloader.Download()

        $installer = $session.CreateUpdateInstaller()
        $installer.Updates = $collection
        $installResult = $installer.Install()

        [pscustomobject]@{
            DownloadResult = [string] $downloadResult.ResultCode
            InstallResult = [string] $installResult.ResultCode
            RebootRequired = [bool] $installResult.RebootRequired
        }
    }

    $spinner = @('|', '/', '-', '\')
    $spinnerIndex = 0
    $started = Get-Date
    Write-Host 'Preparando, baixando e instalando atualizacoes...' -ForegroundColor Cyan

    try {
        while ((Get-Job -Id $job.Id).State -in @('NotStarted', 'Running')) {
            $seconds = [int] ((Get-Date) - $started).TotalSeconds
            Write-Progress -Activity 'Windows Update' -Status ("Baixando/instalando... {0}s" -f $seconds)
            Write-Host ("`r{0} Windows Update em andamento... {1}s" -f $spinner[$spinnerIndex], $seconds) -NoNewline
            $spinnerIndex = ($spinnerIndex + 1) % $spinner.Count
            Start-Sleep -Milliseconds 350
        }

        $job = Get-Job -Id $job.Id
        if ($job.State -eq 'Failed') {
            throw $job.ChildJobs[0].JobStateInfo.Reason
        }

        $result = @(Receive-Job -Job $job -ErrorAction Stop)
        Write-Progress -Activity 'Windows Update' -Completed
        Write-Host "`rWindows Update concluido.                                      "
        return $result[0]
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-WindowsUpdate {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [switch] $Install,
        [switch] $IncludeDrivers,
        [switch] $IncludeOptional,
        [switch] $Reboot
    )

    if ($Install -and -not (Test-IsAdministrator)) {
        throw 'Execute o PowerShell como Administrador para instalar atualizacoes.'
    }

    $updates = @(Get-WindowsUpdateInventory)
    $selected = @(Select-WindowsUpdates -Updates $updates -IncludeDrivers:$IncludeDrivers -IncludeOptional:$IncludeOptional)

    Write-Host ("Encontradas: {0}; selecionadas: {1}." -f $updates.Count, $selected.Count) -ForegroundColor Cyan
    $updates | ForEach-Object {
        $kind = if ($_.IsDriver) { 'driver' } elseif ($_.IsPreview) { 'preview' } elseif ($_.IsOptional) { 'opcional' } else { 'regular' }
        Write-Host ("  [{0}] {1}" -f $kind, $_.Title) -ForegroundColor Yellow
    }

    if (-not $Install) {
        Write-Host 'Previa concluida. Drivers, previews e opcionais nao sao instalados por padrao.' -ForegroundColor Cyan
        return
    }

    if ($selected.Count -eq 0) {
        Write-Host 'Nenhuma atualizacao regular selecionada.' -ForegroundColor Green
        return
    }

    if (-not (Read-YesNo 'Baixar e instalar as atualizacoes selecionadas?')) {
        Write-Host 'Operacao cancelada.' -ForegroundColor Yellow
        return
    }

    try {
        if ($PSCmdlet.ShouldProcess("$($selected.Count) atualizacao(oes)", 'Baixar e instalar')) {
            $installResult = Invoke-WindowsUpdateInstall -UpdateIds @($selected | ForEach-Object { $_.UpdateId })
            Write-MaintenanceLog "Download: $($installResult.DownloadResult); instalacao: $($installResult.InstallResult)"
            Write-Host ("Download: {0}; instalacao: {1}" -f $installResult.DownloadResult, $installResult.InstallResult) -ForegroundColor Green

            if ($installResult.RebootRequired) {
                Write-Warning 'O Windows Update solicitou reinicializacao.'
                if ($Reboot -and (Read-YesNo 'Reiniciar o computador agora?')) {
                    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Reiniciar computador')) {
                        Restart-Computer -Force
                    }
                }
            }
        }
    }
    catch {
        Write-MaintenanceLog -Level ERROR -Message "Falha no Windows Update: $($_.Exception.Message)"
        throw
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WindowsUpdate -Install:$Install -IncludeDrivers:$IncludeDrivers -IncludeOptional:$IncludeOptional -Reboot:$Reboot
}
