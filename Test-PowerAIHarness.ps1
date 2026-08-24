# Test-PowerAIHarness.ps1 - Automated Benchmark Suite (20 Test Scenarios)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Import-Module (Join-Path $PSScriptRoot "src\PowerAI\PowerAI.psd1") -Force

$testCases = @(
    @{ Id = 1;  Type = "Query"; Prompt = "quais pastas existem aqui"; Expected = "Get-ChildItem -Directory" },
    @{ Id = 2;  Type = "Query"; Prompt = "listar apenas arquivos"; Expected = "Get-ChildItem -File" },
    @{ Id = 3;  Type = "Query"; Prompt = "como descobrir qual processo ta usando a porta 3000?"; Expected = "3000" },
    @{ Id = 4;  Type = "Query"; Prompt = "matar processo com id 12345 forcadamente"; Expected = "Stop-Process -Id 12345 -Force" },
    @{ Id = 5;  Type = "Query"; Prompt = "listar os 5 processos que mais usam memoria"; Expected = "WorkingSet|WS|Get-Process" },
    @{ Id = 6;  Type = "Query"; Prompt = "ver meu endereco de ip local"; Expected = "Get-NetIPAddress|ipconfig" },
    @{ Id = 7;  Type = "Query"; Prompt = "limpar a tela do terminal"; Expected = "Clear-Host|cls|Clear" },
    @{ Id = 8;  Type = "Query"; Prompt = "ver branch ativa do git"; Expected = "git branch|git status" },
    @{ Id = 9;  Type = "Query"; Prompt = "procurar texto 'config' em todos os arquivos"; Expected = "Select-String|Get-ChildItem" },
    @{ Id = 10; Type = "Query"; Prompt = "mostrar espaco livre nos discos"; Expected = "Get-PSDrive|Get-Volume|Get-CimInstance" },
    @{ Id = 11; Type = "Fix";   Command = "git bransh"; Error = "bransh is not a git command"; Expected = "git branch" },
    @{ Id = 12; Type = "Fix";   Command = "npm rin dev"; Error = "Unknown command: 'rin'"; Expected = "npm run dev" },
    @{ Id = 13; Type = "Fix";   Command = "git ststus"; Error = "ststus is not a git command"; Expected = "git status" },
    @{ Id = 14; Type = "Fix";   Command = "Get-ChilItem"; Error = "The term 'Get-ChilItem' is not recognized"; Expected = "Get-ChildItem" },
    @{ Id = 15; Type = "Fix";   Command = "git pussh origin main"; Error = "pussh is not a git command"; Expected = "git push origin main" },
    @{ Id = 16; Type = "Fix";   Command = "npm intsall"; Error = "Unknown command: 'intsall'"; Expected = "npm install" },
    @{ Id = 17; Type = "Fix";   Command = "docker ps -a --fotmat"; Error = "unknown flag: --fotmat"; Expected = "docker ps -a --format" },
    @{ Id = 18; Type = "Fix";   Command = "git comit -m 'fix'"; Error = "comit is not a git command"; Expected = "git commit -m" },
    @{ Id = 19; Type = "Fix";   Command = "dotnet biuld"; Error = "Cannot find command biuld"; Expected = "dotnet build" },
    @{ Id = 20; Type = "Fix";   Command = "e as pastas"; Error = "The term 'e' is not recognized"; Expected = "Get-ChildItem -Directory" }
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " [BENCHMARK] INICIANDO TESTES DO POWERAI HARNESS (20 CASOS)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0
$cwd = (Get-Location).Path
$harnessCtx = Get-HarnessEnvironmentContext -Cwd $cwd

foreach ($tc in $testCases) {
    Write-Host "[$($tc.Id)/20] Testando $($tc.Type): " -NoNewline -ForegroundColor Yellow
    if ($tc.Type -eq "Query") {
        Write-Host "'$($tc.Prompt)'" -ForegroundColor White
        $sysPrompt = @"
Voce e um Harness de IA Nativo especializado em Windows PowerShell e CLI.
$harnessCtx
Regras de Comportamento:
- Use o contexto de arquivos e tipo de projeto acima para deduzir o comando exato (ex: se o projeto for Node.js e o usuario disser 'subir projeto', use 'npm run dev'; se for .NET, 'dotnet run'; se for listar pastas, 'Get-ChildItem -Directory').
- NUNCA utilize emojis.
- Sempre responda estritamente em portugues brasileiro (PT-BR) com um JSON puro:
{"suggested_command": "comando PowerShell/CLI exato ou null", "explanation": "explicacao concisa em portugues"}
"@
        $userPrompt = "Pedido do Usuario: $($tc.Prompt)"
    } else {
        Write-Host "'$($tc.Command)' (Erro: $($tc.Error))" -ForegroundColor White
        $sysPrompt = @"
Voce e o Motor de Auto-Correcao do Harness de IA do PowerShell.
$harnessCtx
Analise o comando que falhou e o erro retornado.
Identifique se e erro de digitacao, sintaxe incorreta ou linguagem natural e gere o comando de terminal correto.
NUNCA utilize emojis.
Responda OBRIGATORIAMENTE em portugues brasileiro (PT-BR) com APENAS um objeto JSON:
{"suggested_command": "comando corrigido", "explanation": "explicacao curta em 1 frase em portugues"}
"@
        $userPrompt = "Comando Falhado: $($tc.Command)`nErro Retornado: $($tc.Error)"
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $resp = Invoke-AIRouterRequest -SystemPrompt $sysPrompt -UserPrompt $userPrompt
    $sw.Stop()

    if ($resp.Success) {
        $parsed = Parse-AIJsonResult -RawText $resp.RawResponse
        $suggested = if ($parsed) { $parsed.suggested_command } else { $null }

        $isMatch = $false
        if ($suggested) {
            $patterns = $tc.Expected.Split('|')
            foreach ($p in $patterns) {
                if ($suggested -like "*$p*" -or $suggested -match [regex]::Escape($p)) {
                    $isMatch = $true
                    break
                }
            }
        }

        $timeMs = $sw.ElapsedMilliseconds
        if ($isMatch) {
            $passed++
            Write-Host "   [OK] ($timeMs ms) -> Sugeriu: $suggested" -ForegroundColor Green
        } else {
            $failed++
            Write-Host "   [FALHA] ($timeMs ms) -> Sugeriu: '$suggested' | Esperado: '$($tc.Expected)'" -ForegroundColor Red
        }
    } else {
        $failed++
        Write-Host "   [ERRO] $($resp.Explanation)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " RESULTADO FINAL: $passed/20 ACERTOS ($([math]::Round(($passed/20)*100, 1))%)" -ForegroundColor $(if ($passed -ge 18) { "Green" } else { "Yellow" })
Write-Host "==========================================================" -ForegroundColor Cyan