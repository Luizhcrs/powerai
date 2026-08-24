#!/usr/bin/env bash
# powerai.sh - Native Linux & macOS Terminal AI Harness (Bash & Zsh)
# Usage: source ~/.powerai/powerai.sh or ai <query>

POWERAI_CONFIG_DIR="$HOME/.powerai"
POWERAI_CONFIG_FILE="$POWERAI_CONFIG_DIR/config.json"

# In-Memory Volatile Session Memory (lives and dies with this terminal tab)
declare -a POWERAI_SESSION_MEMORY=()

_powerai_add_session() {
    local query="$1"
    local cmd="$2"
    POWERAI_SESSION_MEMORY+=("Usuario: $query | IA sugeriu: $cmd")
    if [ ${#POWERAI_SESSION_MEMORY[@]} -gt 10 ]; then
        POWERAI_SESSION_MEMORY=("${POWERAI_SESSION_MEMORY[@]:1}")
    fi
}

_powerai_get_context() {
    local cwd="$PWD"
    local os_name="$(uname -s) $(uname -r)"
    local top_files="$(ls -1p "$cwd" 2>/dev/null | grep -v '/$' | head -n 15 | tr '\n' ',' | sed 's/,$//')"
    local top_dirs="$(ls -1d */ 2>/dev/null | head -n 10 | tr '\n' ',' | sed 's/,$//')"
    local git_branch=""
    if [ -d ".git" ]; then
        git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    fi

    local session_history=""
    for item in "${POWERAI_SESSION_MEMORY[@]}"; do
        session_history="$session_history\n- $item"
    done

    cat <<EOF
=== CONTEXTO DO SISTEMA E AMBIENTE ===
- Diretorio Atual (CWD): $cwd
- Sistema Operacional: $os_name
- Usuario: $USER (Home: $HOME)
- Branch Git Ativa: ${git_branch:-N/A}
- Pastas no Diretorio: $top_dirs
- Arquivos no Diretorio: $top_files

=== HISTORICO DA SESSAO ATUAL ===
$session_history
EOF
}

_powerai_query() {
    local user_prompt="$1"
    local is_error="$2"
    local harness_ctx="$(_powerai_get_context)"
    local endpoint="http://localhost:11434/api/chat"
    local model="qwen2.5-coder:1.5b"

    local sys_prompt="Voce e um Harness de IA Nativo especializado em terminais Linux e macOS (Bash/Zsh).
$harness_ctx
REGRAS DE SEGURANCA:
- NUNCA crie, altere ou delete arquivos no disco a menos que solicitado.
- Use comandos nativos POSIX/Linux/macOS (ex: 'pwd', 'ls -la', 'ps aux', 'netstat -tuln' ou 'lsof -i', 'ip a' ou 'ifconfig').
- NUNCA utilize emojis nas respostas.
Responda OBRIGATORIAMENTE em JSON puro:
{\"suggested_command\": \"comando exato\", \"explanation\": \"explicacao direta em portugues\"}"

    local json_payload=$(cat <<EOF
{
  "model": "$model",
  "stream": false,
  "options": { "temperature": 0.0 },
  "messages": [
    { "role": "system", "content": $(echo "$sys_prompt" | jq -s -R .) },
    { "role": "user", "content": $(echo "$user_prompt" | jq -s -R .) }
  ]
}
EOF
)

    local response=$(curl -s -X POST "$endpoint" -H "Content-Type: application/json" -d "$json_payload" --max-time 15)
    local raw_content=$(echo "$response" | jq -r '.message.content // empty' 2>/dev/null)

    if [ -z "$raw_content" ]; then
        echo "[Erro] Falha ao conectar ao Ollama local ($endpoint)."
        return 1
    fi

    # Extract JSON fields
    local cmd=$(echo "$raw_content" | jq -r '.suggested_command // empty' 2>/dev/null)
    local exp=$(echo "$raw_content" | jq -r '.explanation // empty' 2>/dev/null)

    if [ -z "$cmd" ] && [ -z "$exp" ]; then
        echo "$raw_content"
        return 0
    fi

    if [ -n "$exp" ]; then
        echo "$exp"
    fi

    if [ -n "$cmd" ] && [ "$cmd" != "null" ]; then
        echo ""
        echo -e "\033[1;37mComando sugerido:\033[0m \033[1;32m$cmd\033[0m"
        read -p "Executar comando? [Enter/S = Sim | Esc/N = Nao]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[SsYy]$ ]] || [ -z "$REPLY" ]; then
            echo -e "\033[0;32m[Executando] $cmd\033[0m"
            echo ""
            _powerai_add_session "$user_prompt" "$cmd"
            eval "$cmd"
        else
            echo "Cancelado."
        fi
    fi
}

ai() {
    if [ $# -eq 0 ]; then
        echo "[PowerAI] Uso: ai <sua pergunta ou pedido>"
        return 0
    fi
    local query="$*"
    echo "[PowerAI] Processando..."
    _powerai_query "$query" false
}

# Alias '?' para ai
alias '?'='ai'

# --- INTERCEPTOR AUTOMATICO DE COMANDOS DESCONHECIDOS (BASH & ZSH) ---

# Para o Bash: command_not_found_handle
command_not_found_handle() {
    local failed_cmd="$*"
    echo "bash: $1: comando nao encontrado"
    echo "[PowerAI] Analisando erro e contexto..."
    _powerai_query "O comando digitado falhou com comando nao encontrado: $failed_cmd" true
    return 127
}

# Para o Zsh: command_not_found_handler
command_not_found_handler() {
    local failed_cmd="$*"
    echo "zsh: comando nao encontrado: $1"
    echo "[PowerAI] Analisando erro e contexto..."
    _powerai_query "O comando digitado falhou com comando nao encontrado: $failed_cmd" true
    return 127
}
