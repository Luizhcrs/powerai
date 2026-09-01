# PowerAI.psm1 - Agent-Safe, Silent & Intelligent Native Windows Harness

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$script:ConfigPath = Join-Path $env:USERPROFILE ".powerai\config.json"

# In-Memory Volatile Session Memory
if (-not $global:PowerAI_SessionMemory) {
    $global:PowerAI_SessionMemory = [System.Collections.Generic.List[PSCustomObject]]::new()
}

function Add-PowerAISessionTurn {
    param(
        [string]$UserQuery,
        [string]$SuggestedCommand,
        [string]$Explanation
    )
    $entry = [PSCustomObject]@{
        Timestamp        = [System.DateTime]::Now
        UserQuery        = $UserQuery
        SuggestedCommand = $SuggestedCommand
        Explanation      = $Explanation
    }
    $global:PowerAI_SessionMemory.Add($entry)
    while ($global:PowerAI_SessionMemory.Count -gt 10) {
        $global:PowerAI_SessionMemory.RemoveAt(0)
    }
}

function Get-PowerAISessionSummary {
    if (-not $global:PowerAI_SessionMemory -or $global:PowerAI_SessionMemory.Count -eq 0) {
        return "Nenhum historico nesta sessao."
    }
    $sb = [System.Text.StringBuilder]::new()
    $sb.AppendLine("=== HISTORICO DA SESSAO ATUAL ===") | Out-Null
    foreach ($item in $global:PowerAI_SessionMemory) {
        $sb.AppendLine("- Usuario: $($item.UserQuery)") | Out-Null
        if ($item.SuggestedCommand) {
            $sb.AppendLine("  IA sugeriu: $($item.SuggestedCommand)") | Out-Null
        }
    }
    return $sb.ToString()
}

function Clear-PowerAISession {
    [CmdletBinding()]
    param()
    $global:PowerAI_SessionMemory.Clear()
    Write-Host "[OK] Memoria da sessao limpa." -ForegroundColor Cyan
}

function Get-AIPowerShellConfig {
    if (Test-Path $script:ConfigPath) {
        Get-Content $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        $defaultConfig = [PSCustomObject]@{
            Mode = "Auto"
            LocalType = "OpenAICompatible"
            LocalEndpoint = "http://127.0.0.1:5151/v1"
            LocalApiKey = ""
            LocalModel = "mlx-community--Qwen2.5-7B-Instruct-4bit"
            OllamaEndpoint = "http://localhost:11434"
            CloudEndpoint = "https://api.openai.com/v1"
            CloudApiKey = ""
            CloudModel = "gpt-4o-mini"
            AutoSuggestOnErrors = $true
            AutoHealingRetries = 2
            TimeoutSeconds = 25
        }
        Set-AIPowerShellConfig -Config $defaultConfig
        $defaultConfig
    }
}

function Set-AIPowerShellConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Config)
    $dir = Join-Path $env:USERPROFILE ".powerai"
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    $Config | ConvertTo-Json -Depth 5 | Set-Content $script:ConfigPath -Encoding UTF8 -Force
}

function Set-AIPowerShellProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet("Auto", "Local", "Cloud", "Ollama", "LocalOpenAI")]
        [string]$Mode
    )
    $cfg = Get-AIPowerShellConfig
    if ($Mode -eq "Ollama") {
        $cfg.Mode = "Local"
        $cfg.LocalType = "Ollama"
    } elseif ($Mode -eq "LocalOpenAI") {
        $cfg.Mode = "Local"
        $cfg.LocalType = "OpenAICompatible"
    } else {
        $cfg.Mode = $Mode
    }
    Set-AIPowerShellConfig -Config $cfg
    Write-Host "[OK] Provedor PowerAI atualizado para: $Mode" -ForegroundColor Green
}

function Uninstall-PowerAI {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [switch]$Force
    )
    if ($Force -or $PSCmdlet.ShouldProcess("PowerAI", "Desinstalar completamente o PowerAI do sistema")) {
        $uninstallerPath = Join-Path $env:USERPROFILE ".powerai\uninstall.ps1"
        if (Test-Path $uninstallerPath) {
            & $uninstallerPath
        } else {
            irm "https://raw.githubusercontent.com/Luizhcrs/powerai/main/uninstall.ps1" | iex
        }
    }
}

# --- HARNESS: CONTEXT ENGINE WITH WINDOWS KNOWLEDGE ---
function Get-HarnessEnvironmentContext {
    param([string]$Cwd)

    $userHome = $env:USERPROFILE
    $appData = $env:APPDATA
    $localAppData = $env:LOCALAPPDATA
    $docsPath = [System.IO.Path]::Combine($userHome, "Documents")
    $deskPath = [System.IO.Path]::Combine($userHome, "Desktop")
    $downPath = [System.IO.Path]::Combine($userHome, "Downloads")
    $windPath = $env:WINDIR

    $ctx = @{
        Cwd = $Cwd
        UserHome = $userHome
        AppData = $appData
        LocalAppData = $localAppData
        WindowsDir = $windPath
        Documents = $docsPath
        Desktop = $deskPath
        Downloads = $downPath
        Files = @()
        Directories = @()
        GitBranch = $null
        ProjectType = "Desconhecido"
    }

    try {
        $items = Get-ChildItem -Path $Cwd -Force -ErrorAction SilentlyContinue
        $ctx.Directories = ($items | Where-Object { $_.PSIsContainer -and -not $_.Name.StartsWith(".") -and $_.Name -notin @('node_modules', 'bin', 'obj') } | Select-Object -ExpandProperty Name -First 10)
        $ctx.Files = ($items | Where-Object { -not $_.PSIsContainer -and -not $_.Name.StartsWith(".") } | Select-Object -ExpandProperty Name -First 15)

        # Detect Project
        if ($ctx.Files -contains "package.json") { $ctx.ProjectType = "Node.js" }
        elseif ($ctx.Files -match '\.(csproj|sln)$') { $ctx.ProjectType = ".NET / C#" }
        elseif ($ctx.Files -match '(requirements\.txt|pyproject\.toml)$') { $ctx.ProjectType = "Python" }
        elseif ($ctx.Files -contains "Cargo.toml") { $ctx.ProjectType = "Rust" }

        # Git
        if (Test-Path (Join-Path $Cwd ".git")) {
            $branch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($branch) { $ctx.GitBranch = $branch.Trim() }
        }
    } catch {}

    $sessionHistory = Get-PowerAISessionSummary

    $summary = @"
=== CONTEXTO DO SISTEMA E AMBIENTE (POWERSHELL) ===
- Diretorio Atual (CWD): $($ctx.Cwd)
- Pasta do Usuario ($env:USERNAME): $($ctx.UserHome)
- Pasta Windows (C:\Windows): $($ctx.WindowsDir)
- Pasta AppData: $($ctx.AppData)
- Pasta LocalAppData: $($ctx.LocalAppData)
- Pasta Documentos: $($ctx.Documents)
- Pasta Desktop/Area de Trabalho: $($ctx.Desktop)
- Pastas no Diretorio Atual: $([string]::Join(", ", $ctx.Directories))
- Arquivos no Diretorio Atual: $([string]::Join(", ", $ctx.Files))

$sessionHistory
"@
    return $summary
}

# --- HARNESS: ROUTER & DISPATCH ---
function Invoke-AIRouterRequest {
    param(
        [string]$SystemPrompt,
        [string]$UserPrompt
    )

    $cfg = Get-AIPowerShellConfig
    $useLocalOpenAI = $false
    $useOllama = $false
    $useCloud = $false

    $localOpenAIEndpoint = if ($cfg.LocalEndpoint) { $cfg.LocalEndpoint.TrimEnd('/') } else { "http://127.0.0.1:5151/v1" }
    $ollamaEndpoint = if ($cfg.OllamaEndpoint) { $cfg.OllamaEndpoint.TrimEnd('/') } else { "http://localhost:11434" }

    if ($cfg.Mode -eq "Local") {
        if ($cfg.LocalType -eq "OpenAICompatible") {
            $useLocalOpenAI = $true
        } elseif ($cfg.LocalType -eq "Ollama") {
            $useOllama = $true
        } else {
            # Auto detect local provider
            try {
                $headers = @{}
                if (-not [string]::IsNullOrWhiteSpace($cfg.LocalApiKey)) { $headers["Authorization"] = "Bearer $($cfg.LocalApiKey)" }
                $null = Invoke-RestMethod -Uri "$localOpenAIEndpoint/models" -Method Get -Headers $headers -TimeoutSec 2 -ErrorAction Stop
                $useLocalOpenAI = $true
            } catch {
                try {
                    $null = Invoke-RestMethod -Uri "$ollamaEndpoint/api/tags" -Method Get -TimeoutSec 2 -ErrorAction Stop
                    $useOllama = $true
                } catch {
                    $useLocalOpenAI = $true
                }
            }
        }
    } elseif ($cfg.Mode -eq "Cloud") {
        $useCloud = $true
    } else {
        # Auto Mode: check Local OpenAI first, then Ollama, then Cloud
        try {
            $headers = @{}
            if (-not [string]::IsNullOrWhiteSpace($cfg.LocalApiKey)) { $headers["Authorization"] = "Bearer $($cfg.LocalApiKey)" }
            $null = Invoke-RestMethod -Uri "$localOpenAIEndpoint/models" -Method Get -Headers $headers -TimeoutSec 2 -ErrorAction Stop
            $useLocalOpenAI = $true
        } catch {
            try {
                $null = Invoke-RestMethod -Uri "$ollamaEndpoint/api/tags" -Method Get -TimeoutSec 2 -ErrorAction Stop
                $useOllama = $true
            } catch {
                if (-not [string]::IsNullOrWhiteSpace($cfg.CloudApiKey)) {
                    $useCloud = $true
                } else {
                    return @{ Success = $false; Explanation = "Nenhum provedor disponivel (Local API/Ollama inacessiveis e CloudApiKey nao configurada)." }
                }
            }
        }
    }

    if ($useLocalOpenAI) {
        $localUrl = if ($localOpenAIEndpoint.EndsWith("/chat/completions")) { $localOpenAIEndpoint } else { "$localOpenAIEndpoint/chat/completions" }
        $payload = @{
            model = $cfg.LocalModel
            messages = @(
                @{ role = "system"; content = $SystemPrompt },
                @{ role = "user"; content = $UserPrompt }
            )
            temperature = 0.0
        } | ConvertTo-Json -Depth 5

        $headers = @{}
        if (-not [string]::IsNullOrWhiteSpace($cfg.LocalApiKey)) {
            $headers["Authorization"] = "Bearer $($cfg.LocalApiKey)"
        }

        try {
            $res = Invoke-RestMethod -Uri $localUrl -Method Post -Body $payload -Headers $headers -ContentType "application/json; charset=utf-8" -TimeoutSec $cfg.TimeoutSeconds
            return @{
                Success = $true
                RawResponse = $res.choices[0].message.content
                Provider = "Local API ($($cfg.LocalModel))"
            }
        } catch {
            return @{ Success = $false; Explanation = "Falha ao consultar API Local ($localUrl): $_" }
        }
    } elseif ($useOllama) {
        $payload = @{
            model = $cfg.LocalModel
            stream = $false
            messages = @(
                @{ role = "system"; content = $SystemPrompt },
                @{ role = "user"; content = $UserPrompt }
            )
            options = @{ temperature = 0.0 }
        } | ConvertTo-Json -Depth 5

        try {
            $res = Invoke-RestMethod -Uri "$ollamaEndpoint/api/chat" -Method Post -Body $payload -ContentType "application/json; charset=utf-8" -TimeoutSec $cfg.TimeoutSeconds
            return @{
                Success = $true
                RawResponse = $res.message.content
                Provider = "Ollama ($($cfg.LocalModel))"
            }
        } catch {
            return @{ Success = $false; Explanation = "Falha ao consultar Ollama local: $_" }
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($cfg.CloudApiKey)) {
            return @{ Success = $false; Explanation = "CloudApiKey nao configurada em ~/.powerai/config.json" }
        }

        $cloudUrl = "$($cfg.CloudEndpoint.TrimEnd('/'))/chat/completions"
        $payload = @{
            model = $cfg.CloudModel
            messages = @(
                @{ role = "system"; content = $SystemPrompt },
                @{ role = "user"; content = $UserPrompt }
            )
            temperature = 0.0
        } | ConvertTo-Json -Depth 5

        $headers = @{ "Authorization" = "Bearer $($cfg.CloudApiKey)" }

        try {
            $res = Invoke-RestMethod -Uri $cloudUrl -Method Post -Body $payload -Headers $headers -ContentType "application/json; charset=utf-8" -TimeoutSec $cfg.TimeoutSeconds
            return @{
                Success = $true
                RawResponse = $res.choices[0].message.content
                Provider = "Cloud ($($cfg.CloudModel))"
            }
        } catch {
            return @{ Success = $false; Explanation = "Falha na API Cloud: $_" }
        }
    }
}

function Parse-AIJsonResult {
    param([string]$RawText)
    if ([string]::IsNullOrWhiteSpace($RawText)) { return $null }
    $clean = $RawText.Trim()
    if ($clean -match '(?s)\{.*\}') {
        $jsonStr = $matches[0]
        try { return ($jsonStr | ConvertFrom-Json) } catch {}
    }
    return $null
}

function Prompt-UserConfirmation {
    param([string]$PromptText)
    Write-Host $PromptText -NoNewline -ForegroundColor Yellow
    try {
        if ([System.Console]::IsInputRedirected) {
            $response = [System.Console]::ReadLine()
            if ($null -eq $response) {
                # ReadLine() returns $null on EOF (no real input available).
                # Fail closed instead of treating it like an Enter keypress.
                return $false
            }
            return ($response -match "^(y|s|sim|yes)$" -or [string]::IsNullOrWhiteSpace($response))
        } else {
            $key = [System.Console]::ReadKey($true)
            Write-Host ""
            return ($key.Key -eq [System.ConsoleKey]::Enter -or $key.Key -eq [System.ConsoleKey]::Y -or $key.Key -eq [System.ConsoleKey]::S)
        }
    } catch {
        return $false
    }
}

# --- HARNESS: EXECUTION & AUTO-HEALING ENGINE ---
function Execute-HarnessCommand {
    param(
        [string]$CommandToRun,
        [int]$RetryCount = 0
    )

    Write-Host "[Executando] $CommandToRun" -ForegroundColor DarkGreen
    Write-Host ""

    $global:LASTEXITCODE = 0
    $prevErrorCount = $global:Error.Count

    try {
        Invoke-Expression $CommandToRun | Out-Default
    } catch {}
    Write-Host ""

    # AUTO-HEALING: If execution failed, ask model to self-heal
    $hasError = ($global:LASTEXITCODE -ne 0 -and $global:LASTEXITCODE -ne $null) -or ($global:Error.Count -gt $prevErrorCount)
    $cfg = Get-AIPowerShellConfig

    if ($hasError -and $RetryCount -lt $cfg.AutoHealingRetries) {
        $errMessage = if ($global:Error.Count -gt $prevErrorCount) { $global:Error[0].Exception.Message } else { "Exit code: $($global:LASTEXITCODE)" }
        Write-Host "[PowerAI] O comando falhou. Analisando correcao..." -ForegroundColor DarkYellow

        $cwd = (Get-Location).Path
        $harnessCtx = Get-HarnessEnvironmentContext -Cwd $cwd

        $sysPrompt = @"
Voce e o motor de Auto-Healing do Harness do PowerShell.
O comando sugerido executou e FALHOU.
$harnessCtx
Analise o erro retornado e corrija o comando para que funcione no Windows PowerShell.
SEGURANCA: NUNCA crie, sobrescreva ou altere arquivos sem autorizacao explicita. Nao crie scripts temporarios no disco.
Responda OBRIGATORIAMENTE em JSON puro:
{"suggested_command": "comando corrigido", "explanation": "motivo do erro e correcao em portugues"}
"@
        $userPrompt = "Comando que Falhou: $CommandToRun`nErro de Execucao: $errMessage"

        $resp = Invoke-AIRouterRequest -SystemPrompt $sysPrompt -UserPrompt $userPrompt
        if ($resp.Success) {
            $parsed = Parse-AIJsonResult -RawText $resp.RawResponse
            if ($parsed -and -not [string]::IsNullOrWhiteSpace($parsed.suggested_command)) {
                Add-PowerAISessionTurn -UserQuery "Falha ao executar ${CommandToRun} - ${errMessage}" -SuggestedCommand $parsed.suggested_command -Explanation $parsed.explanation
                Write-Host ""
                if ($parsed.explanation) {
                    Write-Host $parsed.explanation -ForegroundColor DarkCyan
                }
                Write-Host "Novo Comando: " -NoNewline -ForegroundColor White
                Write-Host $parsed.suggested_command -ForegroundColor Green

                $confirmed = Prompt-UserConfirmation -PromptText "Executar comando corrigido? [Enter/S = Sim | Esc/N = Nao]: "
                if ($confirmed) {
                    Execute-HarnessCommand -CommandToRun $parsed.suggested_command -RetryCount ($RetryCount + 1)
                } else {
                    Write-Host "Cancelado." -ForegroundColor DarkGray
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Query the AI Harness in natural language directly from PowerShell with rich session context.
#>
function ai {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]]$Query
    )

    $question = $Query -join " "
    if ($question.Trim() -in @("uninstall", "--uninstall", "desinstalar", "/uninstall", "-uninstall")) {
        $confirmed = Prompt-UserConfirmation -PromptText "Deseja realmente desinstalar o PowerAI do seu sistema? [Enter/S = Sim | Esc/N = Nao]: "
        if ($confirmed) {
            Uninstall-PowerAI -Force
        } else {
            Write-Host "Desinstalacao cancelada." -ForegroundColor DarkGray
        }
        return
    }

    if ($question.Trim() -in @("update", "upgrade", "atualizar", "--update")) {
        Write-Host "[PowerAI] Atualizando para a versao mais recente..." -ForegroundColor Cyan
        irm "https://raw.githubusercontent.com/Luizhcrs/powerai/main/install.ps1" | iex
        return
    }

    if ($question.Trim() -in @("version", "-v", "--version", "versao")) {
        Write-Host "PowerAI v1.1.0 (Windows PowerShell & CMD)" -ForegroundColor Green
        try {
            $latest = (Invoke-RestMethod -Uri "https://api.github.com/repos/Luizhcrs/powerai/releases/latest" -TimeoutSec 3 -ErrorAction SilentlyContinue).tag_name
            if ($latest -and $latest -ne "v1.1.0") {
                Write-Host "Nova versao disponivel: $latest. Digite 'ai update' para atualizar." -ForegroundColor Yellow
            } else {
                Write-Host "Voce esta na versao mais recente." -ForegroundColor DarkGray
            }
        } catch {}
        return
    }

    if ($question.Trim() -in @("commit", "cm", "git commit")) {
        $status = git status --short 2>$null
        if (-not $status) {
            Write-Host "Nenhuma alteracao detectada no Git (working tree clean)." -ForegroundColor Yellow
            return
        }
        $diffSample = (git diff 2>$null | Select-Object -First 100) -join "`n"
        $commitPrompt = "Voce e um especialista em Git e Conventional Commits. Analise o diff e gere um commit padronizado: git commit -m '<tipo>: <mensagem>'. Responda em JSON: {`"suggested_command`": `"git commit -m '...'`", `"explanation`": `"motivo`"}"
        $resp = Invoke-AIRouterRequest -SystemPrompt $commitPrompt -UserPrompt "Arquivos: $status`nDiff: $diffSample"
        if ($resp.Success) {
            $parsed = Parse-AIJsonResult -RawText $resp.RawResponse
            if ($parsed.suggested_command) {
                Write-Host ""
                Write-Host "✦ $($parsed.suggested_command)" -ForegroundColor Green
                if ($parsed.explanation) { Write-Host "  ↳ $($parsed.explanation)" -ForegroundColor DarkGray }
                Write-Host ""
                if (Prompt-UserConfirmation -PromptText "Executar commit? [Enter/S = Sim | Esc/N = Nao]: ") {
                    Invoke-Expression $parsed.suggested_command
                } else {
                    Write-Host "Cancelado." -ForegroundColor DarkGray
                }
            }
        }
        return
    }

    if ($Query[0] -in @("explain", "explica", "explicar", "--explain") -and $Query.Length -gt 1) {
        $cmdToExplain = ($Query[1..($Query.Length - 1)]) -join " "
        $explainPrompt = "Explique em detalhes o que este comando PowerShell/CLI faz e o que cada parametro significa: $cmdToExplain. Responda em JSON: {`"suggested_command`": `"`", `"explanation`": `"explicacao detalhada`"}"
        $resp = Invoke-AIRouterRequest -SystemPrompt $explainPrompt -UserPrompt "Explique: $cmdToExplain"
        if ($resp.Success) {
            $parsed = Parse-AIJsonResult -RawText $resp.RawResponse
            Write-Host ""
            Write-Host "✦ Explicacao do Comando: $cmdToExplain" -ForegroundColor Cyan
            Write-Host ""
            Write-Host $parsed.explanation -ForegroundColor Gray
            Write-Host ""
        }
        return
    }

    $cwd = (Get-Location).Path

    Write-Host "[PowerAI] Processando..." -ForegroundColor DarkGray

    $harnessCtx = Get-HarnessEnvironmentContext -Cwd $cwd

    $sysPrompt = @"
Voce e um Harness de IA Nativo especializado em Windows PowerShell.
$harnessCtx
REGRAS FUNDAMENTAIS DE POWERSHELL:
- Para variaveis de ambiente, SEMPRE use `$env:NOME (ex: Set-Location `$env:APPDATA, Set-Location `$env:LOCALAPPDATA, Set-Location `$env:USERPROFILE). NUNCA use sintaxe de CMD (%APPDATA%).
- 'ir para pasta windows' ou 'na pasta windows': Set-Location `$env:WINDIR (ou cd C:\Windows)
- 'ir para appdata': Set-Location `$env:APPDATA
- 'ir para localappdata': Set-Location `$env:LOCALAPPDATA
- 'ir para pasta documentos': Set-Location '$($env:USERPROFILE)\Documents'
- 'ir para desktop' ou 'area de trabalho': Set-Location '$($env:USERPROFILE)\Desktop'
- 'em que pasta estou?' ou 'qual meu diretorio atual?': Get-Location
- 'listar pastas': Get-ChildItem -Directory
- 'listar arquivos': Get-ChildItem -File
- 'listar tudo': Get-ChildItem
- 'qual meu ip': ipconfig /all
- NUNCA utilize emojis nas respostas.

Responda OBRIGATORIAMENTE em JSON puro:
{"suggested_command": "comando exato a executar", "explanation": "explicacao direta em portugues"}
"@

    $userPrompt = "Pedido do Usuario: $question"

    $resp = Invoke-AIRouterRequest -SystemPrompt $sysPrompt -UserPrompt $userPrompt

    if (-not $resp.Success) {
        Write-Host "[Erro] $($resp.Explanation)" -ForegroundColor Yellow
        return
    }

    $parsed = Parse-AIJsonResult -RawText $resp.RawResponse
    $suggestedCmd = if ($parsed) { $parsed.suggested_command } else { $null }
    $explanation = if ($parsed) { $parsed.explanation } else { $resp.RawResponse }

    Add-PowerAISessionTurn -UserQuery $question -SuggestedCommand $suggestedCmd -Explanation $explanation

    if (-not [string]::IsNullOrWhiteSpace($suggestedCmd)) {
        Write-Host ""
        Write-Host "  ✦ $suggestedCmd" -ForegroundColor White
        if ($explanation) {
            Write-Host "    ↳ $explanation" -ForegroundColor DarkGray
        }
        Write-Host ""

        $confirmed = Prompt-UserConfirmation -PromptText "  Executar comando? [Enter/S = Sim | Esc/N = Nao]: "
        if ($confirmed) {
            Write-Host "  [Executando] $suggestedCmd" -ForegroundColor Gray
            Write-Host ""
            Execute-HarnessCommand -CommandToRun $suggestedCmd
        } else {
            Write-Host "  Cancelado." -ForegroundColor DarkGray
        }
    } elseif ($explanation) {
        Write-Host ""
        Write-Host "  ✦ $explanation" -ForegroundColor Gray
        Write-Host ""
    }
}

Set-Alias -Name '?' -Value 'ai' -Option AllScope -Force

<#
.SYNOPSIS
    Interactively captures command failures and asks Harness for immediate correction with session awareness.
#>
function Invoke-AIErrorFix {
    [CmdletBinding()]
    param(
        [string]$FailedCommand,
        [string]$ErrorMessage
    )

    $cwd = (Get-Location).Path
    Write-Host "  ⠋ pensando · analisando erro..." -ForegroundColor DarkGray

    $harnessCtx = Get-HarnessEnvironmentContext -Cwd $cwd

    $sysPrompt = @"
Voce e o Motor de Auto-Correcao do Harness de IA do PowerShell.
$harnessCtx
O usuario digitou algo que causou erro no terminal.
Analise TANTO o texto digitado quanto a mensagem de erro retornada.
REGRAS OBRIGATORIAS:
- No PowerShell, SEMPRE use sintaxe `$env:VAR e NUNCA sintaxe de CMD %VAR%.
- 'no windows' ou 'na pasta windows': Set-Location `$env:WINDIR (ou cd C:\Windows)
- 'ir para appdata': Set-Location `$env:APPDATA
- 'ir para localappdata': Set-Location `$env:LOCALAPPDATA
- 'ir para documentos': Set-Location '$($env:USERPROFILE)\Documents'
- 'ir para desktop': Set-Location '$($env:USERPROFILE)\Desktop'
- 'estou em que pasta?', 'onde estou?': Get-Location
- Erros de digitacao (git pussh, npm rin): comando corrigido.
- Rede/ip: ipconfig /all.
- NUNCA utilize emojis nas respostas.

Responda OBRIGATORIAMENTE em JSON puro:
{"suggested_command": "comando correto a executar", "explanation": "explicacao direta em 1 frase"}
"@

    $userPrompt = "Comando/Texto que falhou: $FailedCommand`nMensagem de Erro do Shell: $ErrorMessage"

    $resp = Invoke-AIRouterRequest -SystemPrompt $sysPrompt -UserPrompt $userPrompt

    if ($resp.Success) {
        $parsed = Parse-AIJsonResult -RawText $resp.RawResponse
        $suggestedCmd = if ($parsed) { $parsed.suggested_command } else { $null }
        $explanation = if ($parsed) { $parsed.explanation } else { $null }

        if ($parsed -and -not [string]::IsNullOrWhiteSpace($suggestedCmd)) {
            Add-PowerAISessionTurn -UserQuery $FailedCommand -SuggestedCommand $suggestedCmd -Explanation $explanation
            Write-Host ""
            Write-Host "  ✦ $suggestedCmd" -ForegroundColor White
            if ($explanation) {
                Write-Host "    ↳ $explanation" -ForegroundColor DarkGray
            }
            Write-Host ""

            $confirmed = Prompt-UserConfirmation -PromptText "  Executar correcao? [Enter/S = Sim | Esc/N = Nao]: "
            if ($confirmed) {
                Write-Host "  [Executando] $suggestedCmd" -ForegroundColor Gray
                Write-Host ""
                Execute-HarnessCommand -CommandToRun $suggestedCmd
            } else {
                Write-Host "  Cancelado." -ForegroundColor DarkGray
            }
        }
    }
}

# --- PROMPT ERROR HOOK INTERCEPTOR ---
$global:PowerAI_LastHandledErrorId = $null
$global:PowerAI_LastHandledExitCodeId = $null

function Register-PowerAIErrorHandler {
    if (-not $global:PowerAI_OriginalPrompt) {
        $global:PowerAI_OriginalPrompt = Get-Content function:\prompt -ErrorAction SilentlyContinue
    }

    function global:prompt {
        # Check non-interactive only if input is redirected
        if ([System.Console]::IsInputRedirected) {
            if ($global:PowerAI_OriginalPrompt) {
                return (Invoke-Command -ScriptBlock ([ScriptBlock]::Create($global:PowerAI_OriginalPrompt)))
            } else {
                return "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
            }
        }

        $cfg = Get-AIPowerShellConfig

        # 1. PowerShell Pipeline Errors
        $lastErr = $global:Error[0]
        $handled = $false

        if ($cfg.AutoSuggestOnErrors -eq $true -and $lastErr -and ($global:PowerAI_LastHandledErrorId -ne $lastErr.GetHashCode())) {
            $global:PowerAI_LastHandledErrorId = $lastErr.GetHashCode()
            $failedCmd = $lastErr.InvocationInfo.Line
            if (-not [string]::IsNullOrWhiteSpace($failedCmd)) {
                $trimmed = $failedCmd.Trim()
                if (-not $trimmed.StartsWith("ai ") -and -not $trimmed.StartsWith("? ") -and ($trimmed -ne "ai") -and ($trimmed -ne "?")) {
                    $errText = $lastErr.Exception.Message
                    Invoke-AIErrorFix -FailedCommand $failedCmd -ErrorMessage $errText
                    $handled = $true
                }
            }
        }

        # 2. Native CLI errors (npm, git, docker) via $LASTEXITCODE
        if (-not $handled -and $cfg.AutoSuggestOnErrors -eq $true -and $global:LASTEXITCODE -ne 0 -and $global:LASTEXITCODE -ne $null) {
            $history = Get-History -Count 1 -ErrorAction SilentlyContinue
            if ($history -and $history.CommandLine -and ($global:PowerAI_LastHandledExitCodeId -ne $history.Id)) {
                $global:PowerAI_LastHandledExitCodeId = $history.Id
                $cmdLine = $history.CommandLine.Trim()
                if (-not $cmdLine.StartsWith("ai ") -and -not $cmdLine.StartsWith("? ") -and ($cmdLine -ne "ai") -and ($cmdLine -ne "?")) {
                    Invoke-AIErrorFix -FailedCommand $cmdLine -ErrorMessage "Command returned non-zero exit code: $($global:LASTEXITCODE)"
                }
            }
        }

        if ($global:PowerAI_OriginalPrompt) {
            Invoke-Command -ScriptBlock ([ScriptBlock]::Create($global:PowerAI_OriginalPrompt))
        } else {
            "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
        }
    }
}

Register-PowerAIErrorHandler
