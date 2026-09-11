# Script remoto de manutenção Windows

Primeira entrega: Debloat Windows 11 conservador.

## Publicacao HTTPS

Envie para `https://projetoalfa.org/win/` estes itens, preservando as subpastas:

- `.htaccess`
- `index.html`
- `menu.ps1`
- `debloat.ps1`
- `windows-update.ps1`
- `anydesk.ps1`
- `limpeza.ps1`
- `SCRIPT.Drivers.Backup.bat`
- `lib/Common.ps1`
- `docs/debloat-policy.md`

Depois, o comando remoto sera:

```powershell
irm https://projetoalfa.org/win | iex
```

O `.htaccess` desativa listagem de diretorio e direciona a pasta diretamente para `menu.ps1`. Nao e necessario expor um indexador de arquivos.

## Uso local

Abra PowerShell como Administrador na pasta do projeto:

```powershell
.\menu.ps1
```

Prévia sem alteração:

```powershell
.\debloat.ps1
```

Aplicação com confirmação:

```powershell
.\debloat.ps1 -Apply
```

O menu remoto agora usa exclusivamente esse dominio HTTPS e carrega os modulos publicados no mesmo servidor. Windows Update instala atualizacoes regulares por padrao; drivers, previews e opcionais ficam separados. AnyDesk baixa somente da fonte oficial, valida a assinatura Authenticode, instala o servico e pede a senha de acesso nao supervisionado sem registra-la.

Backup e restauracao de drivers:

```text
No menu principal, escolha 6.
O script `SCRIPT.Drivers.Backup.bat` sera aberto com o menu proprio dele.
```

Limpeza:

```text
No menu principal, escolha 4.
A limpeza mostra uma previa e remove somente temporarios do usuario e do sistema apos confirmacao.
```
