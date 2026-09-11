# Manutenção Windows 10 e 11

Scripts PowerShell para manutenção administrativa do Windows 10 e 11:

## Uso remoto

Execute com:

```powershell
irm https://projetoalfa.org/win/ | iex
```

Use somente em computadores autorizados e revise as ações antes de aplicar alterações.

## O que faz

- Debloat conservador.
- Windows Update.
- Limpeza de arquivos temporários.
- Instalação e configuração do AnyDesk.
- Backup e restauração de drivers.

## Requisitos

- Windows 10 ou 11.
- PowerShell executado como Administrador.
- Internet para Windows Update, AnyDesk e uso remoto.

O alvo de compatibilidade é Windows 10 versão 1607 ou posterior e Windows 11, usando Windows PowerShell 5.1. O backup de drivers usa a sintaxe moderna do PnPUtil quando disponível e faz fallback para a sintaxe legada.

## Uso

Menu principal:

```powershell
.\menu.ps1
```

Prévia:

```powershell
.\debloat.ps1
.\limpeza.ps1
```

Aplicação:

```powershell
.\debloat.ps1 -Apply
.\limpeza.ps1 -Apply
.\windows-update.ps1 -Install
```

Backup ou restauração de drivers:

```powershell
.\SCRIPT.Drivers.Backup.bat
```
