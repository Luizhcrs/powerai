@echo off
REM ai.cmd - Native Windows CMD bridge to PowerAI Harness
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo [PowerAI] Uso: ai ^<sua pergunta ou pedido^>
    echo Exemplo: ai como listar arquivos da pasta
    exit /b 0
)

set "QUERY=%*"

REM Carrega o modulo PowerAI silenciosamente sem nenhum warning
REM A query passa por variavel de ambiente (nao interpolada na string do -Command)
REM para nao permitir injecao de comandos PowerShell via aspas simples.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Import-Module PowerAI -Force -DisableNameChecking 3>$null; ai $env:QUERY"
