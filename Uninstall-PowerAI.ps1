# Uninstall-PowerAI.ps1 - Desinstalador Local para Windows (PowerShell e CMD)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$localScript = Join-Path $PSScriptRoot "uninstall.ps1"
if (Test-Path $localScript) {
    & $localScript
} else {
    Write-Host "Baixando script de desinstalacao do PowerAI..." -ForegroundColor Yellow
    irm "https://raw.githubusercontent.com/Luizhcrs/powerai/main/uninstall.ps1" | iex
}
