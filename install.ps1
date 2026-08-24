# install.ps1 - Universal Web One-Liner Installer for PowerAI
# Usage: irm https://raw.githubusercontent.com/SEU-USUARIO/power/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [PowerAI] Instalador Automatico para Windows (PS e CMD) " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$binDir = Join-Path $env:USERPROFILE ".powerai\bin"
$moduleDir = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules\PowerAI"
$repoZipUrl = "https://github.com/Luizhcrs/nuno/archive/refs/heads/main.zip"
$tempZip = Join-Path $env:TEMP "powerai_install.zip"
$tempExtract = Join-Path $env:TEMP "powerai_extract"

if (-not (Test-Path $binDir)) { New-Item -Path $binDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $moduleDir)) { New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null }

# 1. Obter arquivos (se rodando localmente ou baixando do GitHub)
$localSource = $PSScriptRoot
$hasLocalSource = $localSource -and (Test-Path (Join-Path $localSource "src\PowerAI"))

if ($hasLocalSource) {
    Write-Host "[1/4] Usando arquivos locais do repositorio..." -ForegroundColor Yellow
    Copy-Item -Path (Join-Path $localSource "ai.cmd") -Destination (Join-Path $binDir "ai.cmd") -Force
    Copy-Item -Path (Join-Path $localSource "src\PowerAI\*") -Destination $moduleDir -Recurse -Force
} else {
    Write-Host "[1/4] Baixando a versao mais recente do PowerAI..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $repoZipUrl -OutFile $tempZip -UseBasicParsing
        if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        $extractedRoot = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
        Copy-Item -Path (Join-Path $extractedRoot.FullName "ai.cmd") -Destination (Join-Path $binDir "ai.cmd") -Force
        Copy-Item -Path (Join-Path $extractedRoot.FullName "src\PowerAI\*") -Destination $moduleDir -Recurse -Force

        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "[Aviso] Falha no download remoto. Certifique-se de configurar a URL do repositorio." -ForegroundColor Yellow
    }
}

# 2. Configurar executaveis e doskey para o CMD ('ai' e '?')
Write-Host "[2/4] Configurando executaveis e atalhos do CMD..." -ForegroundColor Yellow
$autoRunScript = "@echo off`ndoskey ?=ai `$`*"
Set-Content -Path (Join-Path $binDir "cmd_autorun.cmd") -Value $autoRunScript -Force

$autoRunCmdPath = Join-Path $binDir "cmd_autorun.cmd"
try {
    reg.exe add "HKCU\Software\Microsoft\Command Processor" /v AutoRun /t REG_SZ /d "`"$autoRunCmdPath`"" /f | Out-Null
    Write-Host "   [OK] Atalho '?' registrado para o CMD." -ForegroundColor Green
} catch {}

# 3. Configurar PATH do Windows (para o CMD)
Write-Host "[3/4] Configurando PATH do Windows para CMD e PowerShell..." -ForegroundColor Yellow
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
    Write-Host "   [OK] PATH do Windows atualizado com sucesso." -ForegroundColor Green
} else {
    Write-Host "   [OK] PATH do Windows ja configurado." -ForegroundColor Gray
}

# 4. Configurar carregamento automatico silencioso no $PROFILE do PowerShell
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

# 5. Criar configuracao padrao caso nao exista
$configPath = Join-Path $env:USERPROFILE ".powerai\config.json"
if (-not (Test-Path $configPath)) {
    $defaultConfig = [PSCustomObject]@{
        Mode = "Auto"
        OllamaEndpoint = "http://localhost:11434"
        LocalModel = "qwen2.5-coder:1.5b"
        CloudEndpoint = "https://api.openai.com/v1"
        CloudApiKey = ""
        CloudModel = "gpt-4o-mini"
        AutoSuggestOnErrors = $true
        AutoHealingRetries = 2
        TimeoutSeconds = 25
    }
    $defaultConfig | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8 -Force
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [SUCESSO] PowerAI instalado com sucesso no seu Windows!" -ForegroundColor Green
Write-Host ""
Write-Host " - No CMD: Abra um novo terminal e digite: ai <pergunta> ou ? <pergunta>" -ForegroundColor White
Write-Host " - No PowerShell: Abra um novo terminal e digite: ai <pergunta>, ? <pergunta> ou texto livre" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
