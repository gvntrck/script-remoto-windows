@echo off
:menu
cls
echo =================================
echo   BACKUP E RESTAURACAO DE DRIVERS
echo =================================

echo.
echo 1 - Fazer backup dos drivers
echo 2 - Restaurar drivers
echo.
set /p opcao=Digite sua opcao: 

if "%opcao%"=="1" (
    echo.
    echo Criando pasta de backup...
    if not exist "C:\DriversBackup" mkdir "C:\DriversBackup"
    echo.
    echo Iniciando o backup dos drivers...
    dism /online /export-driver /destination:C:\DriversBackup
    echo.
    echo Backup concluido! Os drivers foram salvos em C:\DriversBackup
    pause
    goto menu
)

if "%opcao%"=="2" (
    echo.
    set /p caminho=Digite o caminho onde estao os drivers para restauracao: 
    echo.

    echo Iniciando a restauracao dos drivers de %caminho%...
    for /r "%caminho%" %%f in (*.inf) do (
        echo Instalando driver: %%f
        pnputil /add-driver "%%f" /install
    )
    echo.
    echo Restauracao concluida!
    pause
    goto menu
)

echo.
echo Opcao invalida! Por favor, digite 1 ou 2.
timeout /t 3
goto menu
