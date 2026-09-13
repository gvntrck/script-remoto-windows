Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$menu = Get-Content -Raw (Join-Path $PSScriptRoot '..\menu.ps1')
if ($menu -notmatch '\[Net\.SecurityProtocolType\]::Tls12') {
    throw 'Falha: carregamento remoto nao habilita TLS 1.2.'
}
if ($menu -notmatch "MaintenanceVersion = '1\.9'") {
    throw 'Falha: versao 1.9 nao foi definida no menu.'
}
if ($menu -notmatch "Get-RemoteText 'pc-info\.ps1'" -or $menu -notmatch 'Show-PCInfo') {
    throw 'Falha: modulo de informacoes do PC nao foi integrado ao menu.'
}
if ($menu -notmatch "Get-RemoteText 'admin-local\.ps1'" -or $menu -notmatch 'Invoke-LocalAdminSetup') {
    throw 'Falha: modulo de administrador local nao foi integrado ao menu.'
}

$pwsh = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if (-not $pwsh) {
    $pwsh = (Get-Command powershell.exe -ErrorAction Stop).Source
}

$psi = [Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $pwsh
$psi.Arguments = '-NoLogo -NoProfile -File "{0}"' -f (Join-Path $PSScriptRoot '..\menu.ps1')
$psi.WorkingDirectory = (Join-Path $PSScriptRoot '..')
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$process = [Diagnostics.Process]::new()
$process.StartInfo = $psi
$started = $false
try {
    $started = $process.Start()
    $process.StandardInput.WriteLine('0')
    $process.StandardInput.Close()

    if (-not $process.WaitForExit(2000)) {
        throw 'Falha: o menu nao encerrou apos escolher 0.'
    }
}
finally {
    if ($started -and -not $process.HasExited) {
        $process.Kill()
        $process.WaitForExit()
    }
}

Write-Output 'Menu self-check: ok'
