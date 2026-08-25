<div align="center">

# ✦ PowerAI
### A Camada Cognitiva Invisível & Copiloto para o seu Terminal
*The Invisible Cognitive Layer & AI Copilot for macOS, Linux, and Windows*

<br/>

[**Acesse a Landing Page & Demo Interativo**](https://luizhcrs.github.io/nuno) • [**Instalação Rápida**](#instalação-rápida) • [**Recursos**](#recursos) • [**Arquitetura**](#arquitetura-hexagonal) • [**Configurações**](#configurações)

---

</div>

<br/>

```text
  ✦  P O W E R A I
     Camada Cognitiva & Copiloto para Terminal
     ─────────────────────────────────────────────────────────────

  ✓  1. Idioma do Sistema:       Português (Brasil) (Auto-detectado)
  ✓  2. Ambiente & Ferramentas:  curl, python3, jq prontos
  ✓  3. Provedor de IA:          Ollama Local (http://localhost:11434)
  ✓  4. Modelo Selecionado:      qwen2.5-coder:1.5b (Apple Metal GPU)
  ✓  5. Recursos de Terminal:    Sugestões e correções automáticas ativadas

  ✦ PowerAI instalado com sucesso!
```

<br/>

## Instalação Rápida

Em qualquer terminal limpo, execute uma única linha:

### macOS & Linux (Bash & Zsh)
```bash
curl -fsSL https://raw.githubusercontent.com/Luizhcrs/nuno/main/install.sh | bash
```

### Windows (PowerShell 5.1 / 7+ & CMD)
```powershell
irm https://raw.githubusercontent.com/Luizhcrs/nuno/main/install.ps1 | iex
```

> **Instalação Autônoma**: O instalador é *Self-Healing* — se o sistema não possuir `curl`, `python3` ou `jq`, as dependências são instaladas automaticamente. Para uso com Ollama, o motor e o modelo recomendado são configurados automaticamente.

---

## Recursos

### 1. Local-First & Privacidade Absoluta
- Execução 100% offline via **Ollama** (`http://localhost:11434`) ou APIs Locais compatíveis com OpenAI (**OMLX**, **LM Studio**, **vLLM** em `:5151` / `:8000`).
- Aceleração por hardware nativa (**Apple Metal GPU** no macOS / **CUDA** no Linux & Windows) com tempo de resposta inferior a **800ms**.

### 2. Memória de Saída Contextual de Comandos
- Mantém um buffer estruturado das últimas saídas geradas no terminal (*stdout/stderr*).
- Permite fazer perguntas sobre informações já impressas na tela:
  ```text
  $ ifconfig
  ... (saída de rede com várias interfaces) ...

  $ ai qual é o meu IP local aí na saída?
  ✦ 192.168.0.105 (na interface en0)
  ```

### 3. Zero Risco & Execução Segura
- Operação **Read-Only** por padrão. Nenhum comando é executado sem confirmação explícita no teclado: `[Enter/S = Sim | Esc/N = Não]`.

### 4. Suporte Multilíngue Nativo (i18n)
- Identificação automática do idioma do sistema operacional (**Português**, **Inglês** e **Espanhol**).
- Alternância de idioma a qualquer momento via terminal:
  ```bash
  ai language en   # Switch to English
  ai language es   # Cambiar a Español
  ai language pt   # Volta para Português
  ```

### 5. Interceptação Automática de Erros (Auto-Healing)
- Comandos digitados incorretamente ou inexistentes são interceptados pelo hook do shell, sugerindo a sintaxe correta imediatamente.

---

## Comandos

| Comando | Descrição |
| :--- | :--- |
| `ai <pergunta>` | Consulta em linguagem natural no terminal |
| `? <pergunta>` | Atalho rápido para consultas diretas |
| `ai language <pt\|en\|es>` | Troca o idioma do copiloto em tempo real |
| `ai config` | Exibe as configurações ativas e endpoints |
| `ai uninstall` | Desinstalação completa e limpa do PowerAI |

### Exemplos de Uso:
```bash
# Infraestrutura e rede
? como listar portas abertas escutando conexões
? como matar todos os processos de node travados

# Arquivos e diretórios
? como encontrar todos os arquivos .log com mais de 100mb
? compactar a pasta src em tar.gz excluindo node_modules

# Git e versionamento
? desfazer o ultimo commit mantendo as alteracoes locais
? listar branches remotas que ja foram mescladas
```

---

## Arquitetura Hexagonal

O núcleo do projeto segue o padrão **Ports & Adapters (Hexagonal Architecture)** em C# (.NET Core), desacoplando o Domínio dos Provedores de IA:

```mermaid
graph TD
    subgraph DrivingAdapters ["Adaptadores Primários (Entrada / Inbound)"]
        A1["PowerShell Module (PowerAI.psm1)"]
        A2["Bash & Zsh Harness (powerai.sh)"]
        A3["Response Parser (parse_response.py)"]
    end

    subgraph InboundPorts ["Portas de Entrada (Inbound Ports)"]
        P1["IAIRouter"]
        P2["IContextCollector"]
    end

    subgraph CoreApplication ["Aplicação & Domínio (Core Domain)"]
        C1["AIRouter Orchestrator"]
        C2["ContextCollector Service"]
        C3["Models: PowerAIConfig, SuggestionResult, SessionTurn, EnvironmentContext"]
    end

    subgraph OutboundPorts ["Portas de Saída (Outbound Ports)"]
        P3["ILLMProvider"]
        P4["IConfigRepository"]
        P5["ICliExecutor"]
    end

    subgraph DrivenAdapters ["Adaptadores Secundários (Saída / Outbound)"]
        D1["OllamaProvider"]
        D2["OpenAICompatibleProvider (Local & Cloud)"]
        D3["JsonConfigRepository (~/.powerai/config.json)"]
        D4["ProcessCliExecutor (Git / OS commands)"]
    end

    A1 --> P1
    A2 --> P1
    P1 --> C1
    P2 --> C2
    C1 --> C3
    C2 --> C3
    C1 --> P3
    C1 --> P4
    C2 --> P5
    P3 --> D1
    P3 --> D2
    P4 --> D3
    P5 --> D4
```

---

## Configurações

O arquivo de configuração reside em `~/.powerai/config.json`:

```json
{
  "Mode": "Auto",
  "LocalType": "Ollama",
  "LocalEndpoint": "http://127.0.0.1:5151/v1",
  "LocalApiKey": "",
  "LocalModel": "qwen2.5-coder:1.5b",
  "OllamaEndpoint": "http://localhost:11434",
  "CloudEndpoint": "https://api.openai.com/v1",
  "CloudApiKey": "",
  "CloudModel": "gpt-4o-mini",
  "Language": "pt-BR",
  "AutoSuggestOnErrors": true,
  "AutoHealingRetries": 2,
  "TimeoutSeconds": 25
}
```

---

## Testes Automatizados

Suítes de testes automatizados:
- **Testes Unitários de Domínio e Arquitetura (.NET / xUnit)**: `tests/PowerAI.Tests/`
- **Testes de Integração e Shell Harness**: `tests/test_harness.sh`

Execução dos testes locais:
```bash
./tests/test_harness.sh
```

---

## Licença

Distribuído sob a licença [MIT](LICENSE).
