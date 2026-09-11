[CmdletBinding()]
param()

Set-StrictMode -Version Latest

$script:AnyDeskDownloadUrl = 'https://download.anydesk.com/AnyDesk.exe'
$script:AnyDeskInstallPath = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'AnyDesk'

if ($PSScriptRoot) {
    $commonPath = Join-Path $PSScriptRoot 'lib\Common.ps1'
    if (Test-Path $commonPath) {
        . $commonPath
    }
}

function Test-AnyDeskPasswordLength {
    param([Parameter(Mandatory)] [string] $Password)

    return $Password.Length -ge 8
}

function Get-AnyDeskInstallArguments {
    param(
        [Parameter(Mandatory)] [string] $InstallPath,
        [switch] $ReplaceExisting
    )

    $arguments = @('--install', $InstallPath, '--start-with-win', '--silent', '--update-auto')
    if ($ReplaceExisting) { $arguments += '--remove-first' }
    return $arguments
}

function Save-AnyDeskInstaller {
    param(
        [Parameter(Mandatory)] [string] $Uri,
        [Parameter(Mandatory)] [string] $Destination
    )

    $curl = Get-Command curl.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($curl) {
        Write-Host 'Download via curl com retry...' -ForegroundColor Cyan
        & $curl.Source --location --fail --show-error --retry 3 --retry-delay 2 --connect-timeout 30 --max-time 300 --output $Destination $Uri
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $Destination) -and (Get-Item -LiteralPath $Destination).Length -gt 1MB) {
            return
        }
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        Write-Warning "curl falhou com codigo $LASTEXITCODE; tentando PowerShell."
    }

    $originalProtocol = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = $originalProtocol -bor [Net.SecurityProtocolType]::Tls12
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            try {
                Write-Host ("Download via PowerShell, tentativa {0}/3..." -f $attempt) -ForegroundColor Cyan
                Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing -Headers @{ 'User-Agent' = 'Mozilla/5.0 Windows PowerShell' } -ErrorAction Stop
                if ((Get-Item -LiteralPath $Destination -ErrorAction Stop).Length -le 1MB) {
                    throw 'Arquivo baixado e pequeno demais para ser o instalador.'
                }
                return
            }
            catch {
                Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
                if ($attempt -eq 3) { throw "Falha ao baixar o AnyDesk apos 3 tentativas: $($_.Exception.Message)" }
                Start-Sleep -Seconds 2
            }
        }
    }
    finally {
        [Net.ServicePointManager]::SecurityProtocol = $originalProtocol
    }
}

function Test-AnyDeskRegistryEntry {
    param([Parameter(Mandatory)] $Entry)

    $properties = @($Entry.PSObject.Properties.Name)
    if ($properties -notcontains 'DisplayName' -or $properties -notcontains 'InstallLocation') {
        return $false
    }

    $location = ([string] $Entry.InstallLocation).Trim().Trim('"').Trim("'")
    return $Entry.DisplayName -like 'AnyDesk*' -and -not [string]::IsNullOrWhiteSpace($location)
}

function Get-AnyDeskRegistryExecutablePath {
    param([Parameter(Mandatory)] $Entry)

    if (-not (Test-AnyDeskRegistryEntry -Entry $Entry)) { return $null }
    $location = ([string] $Entry.InstallLocation).Trim().Trim('"').Trim("'")
    if ($location.EndsWith('.exe', [StringComparison]::OrdinalIgnoreCase)) {
        return $location
    }
    return Join-Path $location 'AnyDesk.exe'
}

function Find-AnyDeskExecutable {
    $candidates = @()
    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $programFiles = [Environment]::GetFolderPath('ProgramFiles')

    if ($programFilesX86) { $candidates += Join-Path $programFilesX86 'AnyDesk\AnyDesk.exe' }
    if ($programFiles) { $candidates += Join-Path $programFiles 'AnyDesk\AnyDesk.exe' }

    $command = Get-Command AnyDesk.exe -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }

    foreach ($path in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )) {
        foreach ($item in @(Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object { Test-AnyDeskRegistryEntry -Entry $_ })) {
            $candidates += Get-AnyDeskRegistryExecutablePath -Entry $item
        }
    }

    return @($candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique | Select-Object -First 1)
}

function ConvertTo-ProcessArgument {
    param([Parameter(Mandatory)] [string] $Value)

    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-AnyDeskProcess {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [Parameter(Mandatory)] [string[]] $Arguments,
        [string] $InputText
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = ($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = $null -ne $InputText

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        [void] $process.Start()
        if ($null -ne $InputText) {
            $process.StandardInput.WriteLine($InputText)
            $process.StandardInput.Close()
        }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdout
            StdErr = $stderr
        }
    }
    finally {
        $process.Dispose()
    }
}

function ConvertTo-AnyDeskVersion {
    param([AllowEmptyString()] [string] $Text)

    $match = [regex]::Match($Text, '(?<!\d)\d+(?:\.\d+){1,3}(?!\d)')
    if (-not $match.Success) { return $null }
    try { return [version] $match.Value } catch { return $null }
}

function Get-AnyDeskVersion {
    param([Parameter(Mandatory)] [string] $Executable)

    $result = Invoke-AnyDeskProcess -FilePath $Executable -Arguments @('--version')
    if ($result.ExitCode -ne 0) { return $null }
    return ConvertTo-AnyDeskVersion ($result.StdOut + "`n" + $result.StdErr)
}

function Get-AnyDeskUpdateState {
    param(
        [AllowNull()] [version] $InstalledVersion,
        [AllowNull()] [version] $AvailableVersion
    )

    if ($null -eq $InstalledVersion -or $null -eq $AvailableVersion) { return 'Unknown' }
    if ($InstalledVersion -lt $AvailableVersion) { return 'UpdateRequired' }
    return 'Current'
}

function ConvertTo-PlainText {
    param([Parameter(Mandatory)] [Security.SecureString] $SecureString)

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function Get-AnyDeskPasswordArguments {
    param([AllowNull()] [version] $Version)

    if ($Version -and $Version.Major -lt 7) { return @('--set-password') }
    return @('--set-password', '_unattended_access')
}

function Set-AnyDeskUnattendedPassword {
    param(
        [Parameter(Mandatory)] [string] $Executable,
        [AllowNull()] [version] $Version
    )

    $first = Read-Host 'Digite a senha do acesso nao supervisionado' -AsSecureString
    $second = Read-Host 'Confirme a senha' -AsSecureString
    $firstText = ConvertTo-PlainText $first
    $secondText = ConvertTo-PlainText $second

    try {
        if (-not (Test-AnyDeskPasswordLength $firstText)) {
            throw 'A senha do AnyDesk deve ter pelo menos 8 caracteres.'
        }
        if ($firstText -cne $secondText) {
            throw 'As senhas nao conferem.'
        }

        $arguments = @(Get-AnyDeskPasswordArguments -Version $Version)
        $result = Invoke-AnyDeskProcess -FilePath $Executable -Arguments $arguments -InputText $firstText
        if ($result.ExitCode -ne 0) {
            $details = @(@($result.StdErr.Trim(), $result.StdOut.Trim()) | Where-Object { $_ })
            $detailText = if ($details.Count -gt 0) { $details -join ' | ' } else { 'sem mensagem do AnyDesk' }
            throw ("AnyDesk recusou a senha. Codigo {0}: {1}. Use pelo menos 8 caracteres; prefira 12+ com letras, numeros e simbolos." -f $result.ExitCode, $detailText)
        }
    }
    finally {
        $firstText = $null
        $secondText = $null
        $first.Dispose()
        $second.Dispose()
    }
}

function Install-AnyDeskService {
    for ($attempt = 0; $attempt -lt 15; $attempt++) {
        $services = @(Get-Service -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like 'AnyDesk*' -or $_.DisplayName -like 'AnyDesk*'
        })
        if ($services.Count -gt 0) {
            foreach ($service in $services) {
                Set-Service -Name $service.Name -StartupType Automatic -ErrorAction Stop
                if ($service.Status -ne 'Running') {
                    Start-Service -Name $service.Name -ErrorAction Stop
                }
            }
            return
        }
        Start-Sleep -Seconds 1
    }

    throw 'O servico do AnyDesk nao foi encontrado apos a instalacao.'
}

function Get-AnyDeskValue {
    param(
        [Parameter(Mandatory)] [string] $Executable,
        [Parameter(Mandatory)] [string] $Argument
    )

    $result = Invoke-AnyDeskProcess -FilePath $Executable -Arguments @($Argument)
    if ($result.ExitCode -ne 0) { return 'indisponivel' }
    $line = @($result.StdOut -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)
    if ($line.Count -eq 0) { return 'indisponivel' }
    return $line[0].Trim()
}

function Invoke-AnyDeskSetup {
    if (-not (Test-IsAdministrator)) {
        throw 'Execute o PowerShell como Administrador para instalar e configurar o AnyDesk.'
    }

    $existing = Find-AnyDeskExecutable
    $hadExisting = [bool] $existing
    $downloadPath = $null
    $installedVersion = $null
    $installRequired = -not $hadExisting

    try {
        if ($existing) {
            $installedVersion = Get-AnyDeskVersion -Executable $existing
            $installedLabel = if ($installedVersion) { $installedVersion } else { 'desconhecida' }
            Write-Host ("AnyDesk encontrado: {0} (versao {1})" -f $existing, $installedLabel) -ForegroundColor Cyan
        }

        $downloadPath = Join-Path ([IO.Path]::GetTempPath()) ("AnyDesk-{0}.exe" -f [Guid]::NewGuid())
        Write-Host 'Verificando a versao oficial mais recente...' -ForegroundColor Cyan
        Save-AnyDeskInstaller -Uri $script:AnyDeskDownloadUrl -Destination $downloadPath

        $signature = Get-AuthenticodeSignature -FilePath $downloadPath
        if ($signature.Status -ne 'Valid' -or [string] $signature.SignerCertificate.Subject -notmatch '(?i)AnyDesk') {
            throw 'A assinatura Authenticode do download nao foi validada como AnyDesk.'
        }

        $availableVersion = Get-AnyDeskVersion -Executable $downloadPath
        $availableLabel = if ($availableVersion) { $availableVersion } else { 'desconhecida' }
        Write-Host ("Versao oficial disponivel: {0}" -f $availableLabel) -ForegroundColor Cyan

        if ($hadExisting) {
            switch (Get-AnyDeskUpdateState -InstalledVersion $installedVersion -AvailableVersion $availableVersion) {
                'Current' {
                    Write-Host 'AnyDesk ja esta atualizado. Nenhuma reinstalacao necessaria.' -ForegroundColor Green
                    $installRequired = $false
                }
                'UpdateRequired' {
                    $installRequired = Read-YesNo ("Atualizar AnyDesk de {0} para {1}?" -f $installedVersion, $availableVersion)
                }
                default {
                    $installRequired = Read-YesNo 'Nao foi possivel comparar as versoes. Tentar atualizar mesmo assim?'
                }
            }
        }

        if ($installRequired) {
            $action = if ($hadExisting) { 'Atualizando' } else { 'Instalando' }
            Write-Host ("{0} AnyDesk..." -f $action) -ForegroundColor Cyan
            $arguments = Get-AnyDeskInstallArguments -InstallPath $script:AnyDeskInstallPath -ReplaceExisting:$hadExisting
            $installResult = Invoke-AnyDeskProcess -FilePath $downloadPath -Arguments $arguments
            if ($installResult.ExitCode -ne 0) {
                $details = @(@($installResult.StdErr.Trim(), $installResult.StdOut.Trim()) | Where-Object { $_ })
                $detailText = if ($details.Count -gt 0) { $details -join ' | ' } else { 'sem mensagem do instalador' }
                throw ("Falha na instalacao do AnyDesk. Codigo {0}: {1}" -f $installResult.ExitCode, $detailText)
            }

            $existing = $null
            for ($attempt = 0; $attempt -lt 15 -and -not $existing; $attempt++) {
                $existing = Find-AnyDeskExecutable
                if (-not $existing) { Start-Sleep -Seconds 1 }
            }
            if (-not $existing) { throw 'AnyDesk nao foi encontrado apos a instalacao.' }
            Write-MaintenanceLog 'AnyDesk instalado ou atualizado.'
        }

        Install-AnyDeskService
        Write-Host 'Servico AnyDesk ativo e configurado para iniciar com o Windows.' -ForegroundColor Green

        if (Read-YesNo 'Ativar acesso nao supervisionado agora?') {
            $currentVersion = Get-AnyDeskVersion -Executable $existing
            Set-AnyDeskUnattendedPassword -Executable $existing -Version $currentVersion
            Write-MaintenanceLog 'Acesso nao supervisionado do AnyDesk configurado.'
            Write-Host 'Acesso nao supervisionado configurado.' -ForegroundColor Green
        }

        $id = Get-AnyDeskValue -Executable $existing -Argument '--get-id'
        $alias = Get-AnyDeskValue -Executable $existing -Argument '--get-alias'
        if ($alias -eq 'indisponivel') { $alias = 'nao configurado' }
        Write-Host ("ID: {0}" -f $id) -ForegroundColor Cyan
        Write-Host ("Alias: {0}" -f $alias) -ForegroundColor Cyan
    }
    finally {
        if ($downloadPath -and (Test-Path -LiteralPath $downloadPath)) {
            Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-AnyDeskSetup
}
