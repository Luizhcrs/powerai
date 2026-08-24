# PowerAI - Camada Cognitiva Invisivel para PowerShell

Modulo e extensao inteligente para o PowerShell que atua como uma camada cognitiva transparente:
- Local-First por padrao (via Ollama em localhost:11434), com fallback inteligente para nuvem (OpenAI / Azure OpenAI).
- Intervencao automatica em erros: se um comando falha, a IA analisa stderr, exit code e diretorio de trabalho, sugerindo a correcao com [Enter] para executar.
- Consultas em linguagem natural integradas: use 'ai <pergunta>' ou '? <pergunta>' diretamente na linha de comando sem sair do shell.
- Memoria volatil da sessao atual: o contexto da conversa vive e morre junto com a janela do seu terminal.

---

## Arquitetura

```text
+--------------------------------------------------------+
|                   PowerShell Prompt                    |
|   (Execucoes normais passam 100% nativas e diretas)    |
+---------------------------+----------------------------+
                            |
              +-------------v-------------+
              |      PowerAI Harness      |
              | (Error hook / 'ai' & '?') |
              +-------------+-------------+
                            |
              +-------------v-------------+
              |     PowerAI.Core (C#)     |
              |        AI Router          |
              +------+-------------+------+
                     |             |
                 LOCAL           CLOUD
                     |             |
                +----v----+   +----v----+
                | Ollama  |   | OpenAI  |
                | (Local) |   | (Cloud) |
                +---------+   +---------+
```

---

## Instalacao Rapida Multiplataforma

### No Windows (PowerShell & CMD)
Abra o **PowerShell** e execute:
```powershell
irm https://raw.githubusercontent.com/Luizhcrs/nuno/main/install.ps1 | iex
```

### No Linux e macOS (Bash & Zsh)
Abra o **Terminal** e execute:
```bash
curl -fsSL https://raw.githubusercontent.com/Luizhcrs/nuno/main/install.sh | bash
```

O instalador configura tudo automaticamente:
- **Windows**: Configura o executável `ai.cmd` (para o CMD) e o módulo `PowerAI` (para o PowerShell).
- **Linux/macOS**: Configura no `~/.bashrc` e `~/.zshrc` com hooks nativos do Bash e Zsh (`command_not_found_handle`).
- **Segurança**: Operação Read-Only com proibição de escrita ou alteração silenciosa de arquivos.
- **Memória de Sessão**: Volátil por processo (encerra ao fechar a janela).

---

## Instalacao Local (Desenvolvimento)
- **Windows:** `.\Install-PowerAI.ps1`
- **Linux/macOS:** `bash install.sh`

---

## Comandos e Configuracao

- Perguntar algo em linguagem natural:
  ```powershell
  ai como descubro qual processo esta ouvindo na porta 3000?
  # ou usando o alias curto:
  ? matar processo node travado
  ```

- Trocar de provedor:
  ```powershell
  Set-AIPowerShellProvider Local   # Forca Ollama local
  Set-AIPowerShellProvider Cloud   # Forca Cloud (OpenAI)
  Set-AIPowerShellProvider Auto    # Prioriza Ollama; se offline, faz fallback
  ```

- Arquivo de Configuracao:
  Salvo em `~/.powerai/config.json`
  ```json
  {
    "Mode": "Auto",
    "OllamaEndpoint": "http://localhost:11434",
    "LocalModel": "qwen2.5-coder:1.5b",
    "CloudEndpoint": "https://api.openai.com/v1",
    "CloudApiKey": "",
    "CloudModel": "gpt-4o-mini",
    "AutoSuggestOnErrors": true,
    "TimeoutSeconds": 25
  }
  ```
