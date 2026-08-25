# Install-PowerAI.ps1 - Global Installer for PowerShell & CMD (Prompt de Comando)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [PowerAI] Instalador Global para Windows (PowerShell e CMD)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$binDir = Join-Path $env:USERPROFILE ".powerai\bin"
$moduleDir = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules\PowerAI"
$sourceDir = $PSScriptRoot

if (-not (Test-Path $binDir)) { New-Item -Path $binDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $moduleDir)) { New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null }

# 1. Instalar ai.cmd e cmd_autorun.cmd para o CMD
Write-Host "[1/4] Instalando executaveis globais do CMD em $binDir..." -ForegroundColor Yellow
Copy-Item -Path (Join-Path $sourceDir "ai.cmd") -Destination (Join-Path $binDir "ai.cmd") -Force
if (Test-Path (Join-Path $sourceDir "uninstall.ps1")) {
    Copy-Item -Path (Join-Path $sourceDir "uninstall.ps1") -Destination (Join-Path $env:USERPROFILE ".powerai\uninstall.ps1") -Force
}
$autoRunScript = "@echo off`ndoskey ?=ai `$`*"
Set-Content -Path (Join-Path $binDir "cmd_autorun.cmd") -Value $autoRunScript -Force

# 2. Instalar modulo no repositorio padrao do PowerShell
Write-Host "[2/4] Instalando Modulo PowerShell em $moduleDir..." -ForegroundColor Yellow
Copy-Item -Path (Join-Path $sourceDir "src\PowerAI\*") -Destination $moduleDir -Recurse -Force

# 3. Adicionar bin ao PATH de Usuario
Write-Host "[3/4] Configurando PATH do Windows..." -ForegroundColor Yellow
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
    Write-Host "   [OK] PATH do Windows configurado com sucesso." -ForegroundColor Green
} else {
    Write-Host "   [OK] PATH do Windows ja configurado." -ForegroundColor Gray
}

# 4. Configurar doskey para '?' funcionar no CMD
$autoRunCmdPath = Join-Path $binDir "cmd_autorun.cmd"
try {
    reg.exe add "HKCU\Software\Microsoft\Command Processor" /v AutoRun /t REG_SZ /d "`"$autoRunCmdPath`"" /f | Out-Null
    Write-Host "   [OK] Atalho '?' configurado para o CMD." -ForegroundColor Green
} catch {}

# 5. Configurar $PROFILE do PowerShell
Write-Host "[4/4] Configurando auto-carregamento no perfil do PowerShell..." -ForegroundColor Yellow
$profileDirs = @(
    "C:\Users\$env:USERNAME\Documents\WindowsPowerShell\profile.ps1",
    "C:\Users\$env:USERNAME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
)
foreach ($p in $profileDirs) {
    $parent = Split-Path $p -Parent
    if (-not (Test-Path $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
    Set-Content -Path $p -Value "Import-Module PowerAI -Force -DisableNameChecking" -Force
}
Write-Host "   [OK] PowerShell `$PROFILE configurado silenciosamente." -ForegroundColor Green

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [SUCESSO] Instalacao Concluida!" -ForegroundColor Green
Write-Host ""
Write-Host " - No CMD: Abra qualquer janela e use 'ai <pergunta>' ou '? <pergunta>'" -ForegroundColor White
Write-Host " - No PowerShell: Abra qualquer janela e use 'ai <pergunta>', '? <pergunta>' ou texto livre" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
