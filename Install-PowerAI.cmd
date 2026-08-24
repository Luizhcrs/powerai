@echo off
REM Install-PowerAI.cmd - Global Installer for Windows (PowerShell & CMD)
setlocal enabledelayedexpansion

echo ==========================================================
echo  [PowerAI] Instalador Global para Windows (PowerShell e CMD)
echo ==========================================================
echo.

set "TARGET_DIR=%USERPROFILE%\.powerai\bin"
set "MODULE_DIR=%USERPROFILE%\Documents\WindowsPowerShell\Modules\PowerAI"
set "CURRENT_DIR=%~dp0"

REM 1. Criar diretorios necessarios
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
if not exist "%MODULE_DIR%" mkdir "%MODULE_DIR%"

REM 2. Copiar binarios e scripts para ~/.powerai/bin
echo [1/4] Instalando executaveis globais em %TARGET_DIR%...
copy /Y "%CURRENT_DIR%ai.cmd" "%TARGET_DIR%\ai.cmd" >nul

REM 3. Configurar doskey '?' para o CMD
echo [2/4] Configurando atalho '?' para o CMD...
echo @echo off > "%TARGET_DIR%\cmd_autorun.cmd"
echo doskey ?=ai $* >> "%TARGET_DIR%\cmd_autorun.cmd"
reg add "HKCU\Software\Microsoft\Command Processor" /v AutoRun /t REG_SZ /d "\"%TARGET_DIR%\cmd_autorun.cmd\"" /f >nul

REM 4. Copiar modulo para a pasta padrao de modulos do PowerShell
echo [3/4] Instalando Modulo PowerShell em %MODULE_DIR%...
xcopy /E /I /Y "%CURRENT_DIR%src\PowerAI\*" "%MODULE_DIR%\" >nul

REM 5. Configurar PATH do Windows para o CMD
echo [4/4] Configurando PATH do Windows e PowerShell Profile...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$binDir = [System.IO.Path]::Combine($env:USERPROFILE, '.powerai', 'bin');" ^
  "$userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User');" ^
  "if ($userPath -notlike ('*' + $binDir + '*')) {" ^
  "  [System.Environment]::SetEnvironmentVariable('Path', $userPath + ';' + $binDir, 'User');" ^
  "};" ^
  "$profileDirs = @(" ^
  "  \"C:\Users\$env:USERNAME\Documents\WindowsPowerShell\profile.ps1\"," ^
  "  \"C:\Users\$env:USERNAME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1\"" ^
  ");" ^
  "foreach ($p in $profileDirs) {" ^
  "  $parent = Split-Path $p -Parent;" ^
  "  if (-not (Test-Path $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null };" ^
  "  Set-Content -Path $p -Value 'Import-Module PowerAI -Force -DisableNameChecking' -Force;" ^
  "}"

echo.
echo ==========================================================
echo  [SUCESSO] Instalacao Concluida!
echo.
echo  - No CMD: Abra qualquer janela e digite: ai ^<pergunta^> ou ? ^<pergunta^>
echo  - No PowerShell: Abra qualquer janela e digite: ai ^<pergunta^>, ? ^<pergunta^> ou texto livre
echo ==========================================================
echo.
