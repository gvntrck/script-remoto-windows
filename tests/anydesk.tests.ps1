Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\anydesk.ps1')

$arguments = @(Get-AnyDeskInstallArguments -InstallPath 'C:\Program Files (x86)\AnyDesk')
$updateArguments = @(Get-AnyDeskInstallArguments -InstallPath 'C:\Program Files (x86)\AnyDesk' -ReplaceExisting)
if ($arguments -notcontains '--install') { throw 'Falha: argumento de instalacao ausente.' }
if ($arguments -notcontains '--start-with-win') { throw 'Falha: inicio com Windows ausente.' }
if ($arguments -notcontains '--silent') { throw 'Falha: instalacao silenciosa ausente.' }
if ($updateArguments -notcontains '--remove-first') { throw 'Falha: atualizacao nao substitui a instalacao existente.' }
if (-not (Test-AnyDeskPasswordLength '12345678')) { throw 'Falha: senha valida foi rejeitada.' }
if (Test-AnyDeskPasswordLength '1234567') { throw 'Falha: senha curta foi aceita.' }

$incompleteEntry = [pscustomobject]@{ InstallLocation = 'C:\AnyDesk' }
$validEntry = [pscustomobject]@{ DisplayName = 'AnyDesk'; InstallLocation = 'C:\AnyDesk' }
if (Test-AnyDeskRegistryEntry -Entry $incompleteEntry) { throw 'Falha: entrada sem DisplayName foi aceita.' }
if (-not (Test-AnyDeskRegistryEntry -Entry $validEntry)) { throw 'Falha: entrada valida foi rejeitada.' }

$quotedEntry = [pscustomobject]@{ DisplayName = 'AnyDesk'; InstallLocation = '"C:\Program Files (x86)\AnyDesk"' }
$executableEntry = [pscustomobject]@{ DisplayName = 'AnyDesk'; InstallLocation = '"C:\Program Files (x86)\AnyDesk\AnyDesk.exe"' }
if ((Get-AnyDeskRegistryExecutablePath -Entry $quotedEntry) -ne 'C:\Program Files (x86)\AnyDesk\AnyDesk.exe') {
    throw 'Falha: caminho com aspas nao foi normalizado.'
}
if ((Get-AnyDeskRegistryExecutablePath -Entry $executableEntry) -ne 'C:\Program Files (x86)\AnyDesk\AnyDesk.exe') {
    throw 'Falha: caminho direto do executavel nao foi preservado.'
}

if ((ConvertTo-AnyDeskVersion 'AnyDesk 9.7.15') -ne [version] '9.7.15') { throw 'Falha: versao nao foi extraida.' }
if ((Get-AnyDeskUpdateState -InstalledVersion ([version] '9.7.15') -AvailableVersion ([version] '9.7.15')) -ne 'Current') {
    throw 'Falha: versoes iguais deveriam evitar reinstalacao.'
}
if ((Get-AnyDeskUpdateState -InstalledVersion ([version] '9.6.0') -AvailableVersion ([version] '9.7.15')) -ne 'UpdateRequired') {
    throw 'Falha: versao antiga nao solicitou atualizacao.'
}

$modernPasswordArguments = @(Get-AnyDeskPasswordArguments -Version ([version] '9.7.15'))
$legacyPasswordArguments = @(Get-AnyDeskPasswordArguments -Version ([version] '6.3.5'))
if ($modernPasswordArguments -notcontains '_unattended_access') {
    throw 'Falha: AnyDesk 7+ nao usa o perfil de acesso nao supervisionado.'
}
if ($legacyPasswordArguments -contains '_unattended_access') {
    throw 'Falha: AnyDesk legado recebeu perfil nao suportado.'
}

Write-Output 'AnyDesk self-check: ok'
