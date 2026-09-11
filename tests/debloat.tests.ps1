Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot '..\debloat.ps1')

if (-not (Test-AppxPolicyMatch -Name 'Microsoft.XboxApp' -Patterns $script:DebloatPolicy.Remove)) {
    throw 'Falha: pacote removivel nao foi reconhecido.'
}

if (Test-AppxPolicyMatch -Name 'Microsoft.WindowsStore' -Patterns $script:DebloatPolicy.Remove) {
    throw 'Falha: Microsoft Store entrou na lista de remocao.'
}

if (-not (Test-AppxPolicyMatch -Name 'Microsoft.VCLibs.140.00' -Patterns $script:DebloatPolicy.Protect)) {
    throw 'Falha: framework protegido nao foi reconhecido.'
}

Write-Output 'Debloat self-check: ok'
