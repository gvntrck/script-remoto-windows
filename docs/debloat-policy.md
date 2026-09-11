# Política do Debloat Windows 11

Primeira versão: conservadora. O script só remove nomes de pacote listados explicitamente em `debloat.ps1`.

## Remover

- `Clipchamp.Clipchamp`
- `Microsoft.BingNews`
- `Microsoft.BingWeather`
- `Microsoft.GamingApp`
- `Microsoft.MicrosoftSolitaireCollection`
- Pacotes Xbox: `Microsoft.Xbox.TCUI`, `Microsoft.XboxApp`, `Microsoft.XboxGameOverlay`, `Microsoft.XboxGamingOverlay`, `Microsoft.XboxIdentityProvider` e `Microsoft.XboxSpeechToTextOverlay`

O script aplica a mesma regra a pacotes instalados e provisionados. Pacotes ausentes são ignorados.

## Opcional — não remover nesta versão

Copilot, Teams, Outlook novo, OneDrive, Power Automate, Phone Link, Widgets, OneNote, Cortana e apps de comunicação. A política da empresa deve definir esses itens antes de qualquer inclusão.

## Manter/proteger

Microsoft Store, App Installer, frameworks (`VCLibs`, `UI.Xaml`, `.NET.Native`, `WindowsAppRuntime`), Calculadora, Ferramenta de Captura, Bloco de Notas, Terminal e Fotos.

O código possui uma lista de proteção adicional. Mesmo que um padrão removível seja alterado no futuro, itens protegidos não podem ser removidos.

## Operação

1. Execute `menu.ps1` como Administrador.
2. Revise a lista encontrada.
3. Confirme somente se a política foi validada para aquele equipamento.

Sem `-Apply`, `debloat.ps1` apenas mostra a política. Com `-Apply`, ele pede confirmação, registra sucesso/erro sem armazenar segredos e trata instalação atual e provisionamento separadamente.

Não há wildcard genérico para “apps de fabricante” ou “apps promocionais”: nomes variam por imagem OEM e versão do Windows. Cada pacote novo deve ser identificado e aprovado antes de entrar na lista.
