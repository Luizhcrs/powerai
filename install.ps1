# install.ps1 - Universal Modern & Interactive Installer for PowerAI (Windows)
# Usage: irm https://raw.githubusercontent.com/Luizhcrs/powerai/main/install.ps1 | iex

param(
    [switch]$Quick,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

Clear-Host
Write-Host ""
Write-Host "  ✦  P O W E R A I" -ForegroundColor White
Write-Host "     Camada Cognitiva & Copiloto para Terminal" -ForegroundColor Gray
Write-Host "     ───────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$powerAiDir = Join-Path $env:USERPROFILE ".powerai"
$binDir = Join-Path $powerAiDir "bin"
$moduleDir = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules\PowerAI"
$repoZipUrl = "https://github.com/Luizhcrs/powerai/archive/refs/heads/main.zip"
$tempZip = Join-Path $env:TEMP "powerai_install.zip"
$tempExtract = Join-Path $env:TEMP "powerai_extract"

if (-not (Test-Path $powerAiDir)) { New-Item -Path $powerAiDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $binDir)) { New-Item -Path $binDir -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $moduleDir)) { New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null }

# Defaults
$chosenMode = "Auto"
$chosenLocalType = "Ollama"
$chosenLocalEndpoint = "http://127.0.0.1:5151/v1"
$chosenLocalApiKey = ""
$chosenLocalModel = "qwen2.5-coder:1.5b"
$chosenOllamaEndpoint = "http://localhost:11434"
$chosenCloudEndpoint = "https://api.openai.com/v1"
$chosenCloudApiKey = if ($env:OPENAI_API_KEY) { $env:OPENAI_API_KEY } else { "" }
$chosenCloudModel = "gpt-4o-mini"
$chosenAutoSuggest = $true

if (-not $Quick -and -not [System.Console]::IsInputRedirected) {
    Write-Host "  1. Selecione o Provedor de IA Principal:" -ForegroundColor Gray
    Write-Host "     ╭─────────────────────────────────────────────────────────────╮" -ForegroundColor DarkGray
    Write-Host "     │  1) Ollama Local  (Recomendado: ultrarrápido, offline, <1s)  │" -ForegroundColor Gray
    Write-Host "     │  2) API Local     (OMLX, LM Studio, vLLM em :5151 / :8000)   │" -ForegroundColor Gray
    Write-Host "     │  3) Nuvem         (OpenAI gpt-4o-mini / Groq / OpenRouter)  │" -ForegroundColor Gray
    Write-Host "     │  4) Automático    (Detecta localmente e faz fallback nuvem) │" -ForegroundColor Gray
    Write-Host "     ╰─────────────────────────────────────────────────────────────╯" -ForegroundColor DarkGray

    Write-Host "     Opção [1-4, Padrão: 1]: " -NoNewline -ForegroundColor DarkGray
    $choice = Read-Host
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

    switch ($choice) {
        "2" {
            $chosenMode = "Local"
            $chosenLocalType = "OpenAICompatible"
            Write-Host ""
            Write-Host "  2. Configuração da API Local:" -ForegroundColor Gray
            Write-Host "     Endpoint [Padrão: http://127.0.0.1:5151/v1]: " -NoNewline -ForegroundColor DarkGray
            $ep = Read-Host
            if (-not [string]::IsNullOrWhiteSpace($ep)) { $chosenLocalEndpoint = $ep }
            Write-Host "     Nome do Modelo [Padrão: qwen2.5-coder:1.5b]: " -NoNewline -ForegroundColor DarkGray
            $lm = Read-Host
            if (-not [string]::IsNullOrWhiteSpace($lm)) { $chosenLocalModel = $lm }
            Write-Host "     API Key (opcional se não exigir): " -NoNewline -ForegroundColor DarkGray
            $chosenLocalApiKey = Read-Host
        }
        "3" {
            $chosenMode = "Cloud"
            Write-Host ""
            Write-Host "  2. Configuração da Nuvem (OpenAI / Groq):" -ForegroundColor Gray
            Write-Host "     OpenAI / Groq API Key: " -NoNewline -ForegroundColor DarkGray
            $ck = Read-Host
            if (-not [string]::IsNullOrWhiteSpace($ck)) { $chosenCloudApiKey = $ck }
            Write-Host "     Modelo [Padrão: gpt-4o-mini]: " -NoNewline -ForegroundColor DarkGray
            $cm = Read-Host
            if (-not [string]::IsNullOrWhiteSpace($cm)) { $chosenCloudModel = $cm }
        }
        "4" {
            $chosenMode = "Auto"
            $chosenLocalType = "Ollama"
        }
        Default {
            $chosenMode = "Auto"
            $chosenLocalType = "Ollama"
            Write-Host ""
            Write-Host "  2. Configuração do Ollama Local:" -ForegroundColor Gray
            Write-Host "     Modelo [Padrão: qwen2.5-coder:1.5b]: " -NoNewline -ForegroundColor DarkGray
            $om = Read-Host
            if (-not [string]::IsNullOrWhiteSpace($om)) { $chosenLocalModel = $om }
        }
    }

    Write-Host ""
    Write-Host "  3. Recursos do Terminal:" -ForegroundColor Gray
    Write-Host "     Ativar sugestões e correções automáticas em erros? [S/n]: " -NoNewline -ForegroundColor DarkGray
    $as = Read-Host
    if ($as -match "^[Nn]$") {
        $chosenAutoSuggest = $false
    }
}

Write-Host ""
Write-Host "  4. Instalando e configurando arquivos:" -ForegroundColor Gray

# 1. Obter arquivos (se rodando localmente ou baixando do GitHub)
$localSource = $PSScriptRoot
$hasLocalSource = $localSource -and (Test-Path (Join-Path $localSource "src\PowerAI"))

if ($hasLocalSource) {
    Copy-Item -Path (Join-Path $localSource "ai.cmd") -Destination (Join-Path $binDir "ai.cmd") -Force
    if (Test-Path (Join-Path $localSource "uninstall.ps1")) {
        Copy-Item -Path (Join-Path $localSource "uninstall.ps1") -Destination (Join-Path $powerAiDir "uninstall.ps1") -Force
    }
    Copy-Item -Path (Join-Path $localSource "src\PowerAI\*") -Destination $moduleDir -Recurse -Force
} else {
    try {
        Invoke-WebRequest -Uri $repoZipUrl -OutFile $tempZip -UseBasicParsing
        if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        $extractedRoot = Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1
        Copy-Item -Path (Join-Path $extractedRoot.FullName "ai.cmd") -Destination (Join-Path $binDir "ai.cmd") -Force
        if (Test-Path (Join-Path $extractedRoot.FullName "uninstall.ps1")) {
            Copy-Item -Path (Join-Path $extractedRoot.FullName "uninstall.ps1") -Destination (Join-Path $powerAiDir "uninstall.ps1") -Force
        }
        Copy-Item -Path (Join-Path $extractedRoot.FullName "src\PowerAI\*") -Destination $moduleDir -Recurse -Force

        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "   [Aviso] Falha no download remoto. Certifique-se de configurar a URL do repositorio." -ForegroundColor Yellow
    }
}

# 2. Configurar executaveis e doskey para o CMD ('ai' e '?')
$autoRunScript = "@echo off`ndoskey ?=ai `$`*"
Set-Content -Path (Join-Path $binDir "cmd_autorun.cmd") -Value $autoRunScript -Force

$autoRunCmdPath = Join-Path $binDir "cmd_autorun.cmd"
try {
    reg.exe add "HKCU\Software\Microsoft\Command Processor" /v AutoRun /t REG_SZ /d "`"$autoRunCmdPath`"" /f | Out-Null
} catch {}

# 3. Configurar PATH do Windows (para o CMD)
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
}

# 4. Configurar carregamento automatico silencioso no $PROFILE do PowerShell
$profileDirs = @(
    "C:\Users\$env:USERNAME\Documents\WindowsPowerShell\profile.ps1",
    "C:\Users\$env:USERNAME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
)
foreach ($p in $profileDirs) {
    $parent = Split-Path $p -Parent
    if (-not (Test-Path $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
    Set-Content -Path $p -Value "Import-Module PowerAI -Force -DisableNameChecking" -Force
}

# 5. Criar configuracao personalizada
$configPath = Join-Path $env:USERPROFILE ".powerai\config.json"
$configObj = [PSCustomObject]@{
    Mode = $chosenMode
    LocalType = $chosenLocalType
    LocalEndpoint = $chosenLocalEndpoint
    LocalApiKey = $chosenLocalApiKey
    LocalModel = $chosenLocalModel
    OllamaEndpoint = $chosenOllamaEndpoint
    CloudEndpoint = $chosenCloudEndpoint
    CloudApiKey = $chosenCloudApiKey
    CloudModel = $chosenCloudModel
    AutoSuggestOnErrors = $chosenAutoSuggest
    AutoHealingRetries = 2
    TimeoutSeconds = 25
}
$configObj | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8 -Force

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  ✦  PowerAI instalado com sucesso!" -ForegroundColor White
Write-Host ""
Write-Host "    • Provedor:  $chosenMode ($chosenLocalModel)" -ForegroundColor Gray
Write-Host "    • Destino:   $moduleDir" -ForegroundColor DarkGray
Write-Host "    • Config:    $configPath" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    Para usar no terminal:" -ForegroundColor Gray
Write-Host "      - No PowerShell: Abra um novo terminal e use: ai <pergunta> ou ? <pergunta>" -ForegroundColor White
Write-Host "      - No CMD:        Abra um novo terminal e use: ai <pergunta> ou ? <pergunta>" -ForegroundColor White
Write-Host "  ─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
