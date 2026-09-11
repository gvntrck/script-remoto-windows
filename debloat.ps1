[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
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

$script:DebloatPolicy = [ordered]@{
    Remove = @(
        'Clipchamp.Clipchamp',
        'Microsoft.BingNews',
        'Microsoft.BingWeather',
        'Microsoft.GamingApp',
        'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.Xbox.TCUI',
        'Microsoft.XboxApp',
        'Microsoft.XboxGameOverlay',
        'Microsoft.XboxGamingOverlay',
        'Microsoft.XboxIdentityProvider',
        'Microsoft.XboxSpeechToTextOverlay'
    )
    Protect = @(
        'Microsoft.WindowsStore',
        'Microsoft.DesktopAppInstaller',
        'Microsoft.VCLibs*',
        'Microsoft.UI.Xaml*',
        'Microsoft.NET.Native*',
        'Microsoft.WindowsAppRuntime*',
        'Microsoft.WindowsCalculator',
        'Microsoft.ScreenSketch',
        'Microsoft.WindowsNotepad',
        'Microsoft.WindowsTerminal',
        'Microsoft.Windows.Photos'
    )
}

function Test-AppxPolicyMatch {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string[]] $Patterns
    )

    return $null -ne ($Patterns | Where-Object { $Name -like $_ } | Select-Object -First 1)
}

function Get-DebloatInventory {
    if (-not (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)) {
        throw 'Este script precisa ser executado no Windows com o modulo Appx disponivel.'
    }

    $installed = @(Get-AppxPackage -AllUsers -ErrorAction Stop | Where-Object {
        (Test-AppxPolicyMatch -Name $_.Name -Patterns $script:DebloatPolicy.Remove) -and
        -not (Test-AppxPolicyMatch -Name $_.Name -Patterns $script:DebloatPolicy.Protect)
    })

    $provisioned = @()
    if (Get-Command Get-AppxProvisionedPackage -ErrorAction SilentlyContinue) {
        $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object {
            (Test-AppxPolicyMatch -Name $_.DisplayName -Patterns $script:DebloatPolicy.Remove) -and
            -not (Test-AppxPolicyMatch -Name $_.DisplayName -Patterns $script:DebloatPolicy.Protect)
        })
    }

    [pscustomobject]@{
        Installed = $installed
        Provisioned = $provisioned
    }
}

function Show-DebloatPlan {
    Write-Host 'Debloat conservador - somente itens explicitamente classificados como remover.' -ForegroundColor Cyan
    Write-Host "`nPadroes removiveis:"
    $script:DebloatPolicy.Remove | ForEach-Object { Write-Host "  - $_" }
    Write-Host "`nComponentes protegidos:"
    $script:DebloatPolicy.Protect | ForEach-Object { Write-Host "  - $_" }
    Write-Host "`nNada e alterado nesta previa."
}

function Invoke-Debloat {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([switch] $Apply)

    if (-not (Test-IsAdministrator)) {
        throw 'Execute o PowerShell como Administrador para inspecionar e alterar pacotes de todos os usuarios.'
    }

    $inventory = Get-DebloatInventory
    $installed = @($inventory.Installed)
    $provisioned = @($inventory.Provisioned)

    Write-Host ("Encontrados: {0} pacote(s) instalado(s), {1} provisionado(s)." -f $installed.Count, $provisioned.Count) -ForegroundColor Cyan

    if ($installed.Count -eq 0 -and $provisioned.Count -eq 0) {
        Write-Host 'Nenhum pacote da politica foi encontrado.' -ForegroundColor Green
        return
    }

    $installed | ForEach-Object { Write-Host ("  instalado: {0}" -f $_.Name) -ForegroundColor Yellow }
    $provisioned | ForEach-Object { Write-Host ("  provisionado: {0}" -f $_.DisplayName) -ForegroundColor Yellow }

    if (-not $Apply) {
        Write-Host "`nPrevia concluida. Use -Apply para remover apos revisar a lista." -ForegroundColor Cyan
        return
    }

    if (-not (Read-YesNo 'Aplicar a remoção agora?')) {
        Write-Host 'Operacao cancelada.' -ForegroundColor Yellow
        return
    }

    foreach ($package in $installed) {
        try {
            if ($PSCmdlet.ShouldProcess($package.PackageFullName, 'Remover pacote instalado para todos os usuários')) {
                Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Stop
                Write-MaintenanceLog "Removido instalado: $($package.Name)"
                Write-Host ("Removido: {0}" -f $package.Name) -ForegroundColor Green
            }
        }
        catch {
            Write-MaintenanceLog -Level ERROR -Message "Falha ao remover instalado $($package.Name): $($_.Exception.Message)"
            Write-Warning ("Falha ao remover {0}: {1}" -f $package.Name, $_.Exception.Message)
        }
    }

    foreach ($package in $provisioned) {
        try {
            if ($PSCmdlet.ShouldProcess($package.PackageName, 'Remover pacote provisionado para novos usuários')) {
                Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop | Out-Null
                Write-MaintenanceLog "Removido provisionado: $($package.DisplayName)"
                Write-Host ("Removido provisionado: {0}" -f $package.DisplayName) -ForegroundColor Green
            }
        }
        catch {
            Write-MaintenanceLog -Level ERROR -Message "Falha ao remover provisionado $($package.DisplayName): $($_.Exception.Message)"
            Write-Warning ("Falha ao remover provisionado {0}: {1}" -f $package.DisplayName, $_.Exception.Message)
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $Apply) {
        Show-DebloatPlan
    }
    else {
        Invoke-Debloat -Apply
    }
}
