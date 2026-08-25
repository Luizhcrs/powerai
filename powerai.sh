#!/usr/bin/env bash
# powerai.sh - Native Linux & macOS Terminal AI Harness (Bash & Zsh)
# Usage: source ~/.powerai/powerai.sh or ai <query>

POWERAI_VERSION="v1.0.0"
POWERAI_CONFIG_DIR="$HOME/.powerai"
POWERAI_CONFIG_FILE="$POWERAI_CONFIG_DIR/config.json"
POWERAI_SPINNER_PID=""

_powerai_check_update() {
    local quiet="$1"
    local latest_tag=""
    if command -v curl >/dev/null 2>&1; then
        latest_tag=$(curl -s --max-time 2 "https://api.github.com/repos/Luizhcrs/powerai/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null)
    fi

    if [ -n "$latest_tag" ] && [ "$latest_tag" != "null" ]; then
        if [ "$latest_tag" != "$POWERAI_VERSION" ]; then
            echo ""
            echo -e "  \033[1;33m✦ Nova versão disponível:\033[0m \033[1m$latest_tag\033[0m \033[38;5;244m(Versão atual: $POWERAI_VERSION)\033[0m"
            echo -e "    Execute \033[1;37mai update\033[0m para atualizar instantaneamente."
            echo ""
            return 0
        elif [ "$quiet" != "true" ]; then
            echo "  ✓ PowerAI já está na versão mais recente ($POWERAI_VERSION)."
            return 0
        fi
    elif [ "$quiet" != "true" ]; then
        echo "  [PowerAI] Versão atual: $POWERAI_VERSION"
    fi
}

_powerai_self_update() {
    echo "=========================================================="
    echo " [PowerAI] Atualização do Sistema"
    echo "=========================================================="
    echo -n "  Baixando versão mais recente do GitHub... "

    local tmp_sh=$(mktemp /tmp/powerai_update.XXXXXX 2>/dev/null || echo "/tmp/powerai_update_$$.sh")
    if curl -fsSL "https://raw.githubusercontent.com/Luizhcrs/powerai/main/powerai.sh" -o "$tmp_sh" 2>/dev/null; then
        if bash -n "$tmp_sh" 2>/dev/null || zsh -n "$tmp_sh" 2>/dev/null; then
            mv "$tmp_sh" "$POWERAI_CONFIG_DIR/powerai.sh"
            chmod +x "$POWERAI_CONFIG_DIR/powerai.sh"
            
            curl -fsSL "https://raw.githubusercontent.com/Luizhcrs/powerai/main/uninstall.sh" -o "$POWERAI_CONFIG_DIR/uninstall.sh" 2>/dev/null || true
            chmod +x "$POWERAI_CONFIG_DIR/uninstall.sh" 2>/dev/null || true
            
            echo -e "\033[1;32m[OK]\033[0m"
            echo ""
            echo "  ✓ PowerAI atualizado com sucesso para a versão mais recente!"
            echo "    Para recarregar imediatamente no terminal atual: source ~/.powerai/powerai.sh"
            echo ""
        else
            echo -e "\033[1;31m[Falha]\033[0m"
            echo "  Erro na validação do script baixado. A versão anterior foi mantida."
            rm -f "$tmp_sh"
        fi
    else
        echo -e "\033[1;31m[Falha]\033[0m"
        echo "  Não foi possível conectar ao GitHub. Verifique sua conexão com a internet."
        rm -f "$tmp_sh"
    fi
}

# In-Memory Volatile Session Memory (lives and dies with this terminal tab)
declare -a POWERAI_SESSION_MEMORY=()

_powerai_add_session() {
    local query="$1"
    local cmd="$2"
    local output="$3"

    local turn_data="Query: $query"
    [ -n "$cmd" ] && turn_data="$turn_data\nCommand: $cmd"
    if [ -n "$output" ]; then
        local truncated_out=$(echo "$output" | head -n 120)
        turn_data="$turn_data\nTerminal Output:\n$truncated_out"
    fi

    POWERAI_SESSION_MEMORY+=("$turn_data")
    if [ ${#POWERAI_SESSION_MEMORY[@]} -gt 6 ]; then
        POWERAI_SESSION_MEMORY=("${POWERAI_SESSION_MEMORY[@]:1}")
    fi
}

_powerai_load_config() {
    POWERAI_MODE="Auto"
    POWERAI_LOCAL_TYPE="Ollama"
    POWERAI_LOCAL_ENDPOINT="http://127.0.0.1:5151/v1"
    POWERAI_LOCAL_API_KEY=""
    POWERAI_LOCAL_MODEL="qwen2.5-coder:1.5b"
    POWERAI_OLLAMA_ENDPOINT="http://localhost:11434"
    POWERAI_CLOUD_ENDPOINT="https://api.openai.com/v1"
    POWERAI_CLOUD_API_KEY="${OPENAI_API_KEY:-}"
    POWERAI_CLOUD_MODEL="gpt-4o-mini"
    POWERAI_TIMEOUT=25
    POWERAI_AUTO_SUGGEST=true
    POWERAI_LANGUAGE="pt-BR"

    # Auto-detect language if not explicitly configured
    if [[ "${LANG:-}" =~ ^es ]] || [[ "${LC_ALL:-}" =~ ^es ]]; then
        POWERAI_LANGUAGE="es-ES"
    elif [[ "${LANG:-}" =~ ^en ]] || [[ "${LC_ALL:-}" =~ ^en ]]; then
        POWERAI_LANGUAGE="en-US"
    fi

    if [ -f "$POWERAI_CONFIG_FILE" ]; then
        local m=$(jq -r '.Mode // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$m" ] && POWERAI_MODE="$m"

        local lt=$(jq -r '.LocalType // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$lt" ] && POWERAI_LOCAL_TYPE="$lt"

        local le=$(jq -r '.LocalEndpoint // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$le" ] && POWERAI_LOCAL_ENDPOINT="$le"

        local lk=$(jq -r '.LocalApiKey // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$lk" ] && POWERAI_LOCAL_API_KEY="$lk"

        local lm=$(jq -r '.LocalModel // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$lm" ] && POWERAI_LOCAL_MODEL="$lm"

        local oe=$(jq -r '.OllamaEndpoint // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$oe" ] && POWERAI_OLLAMA_ENDPOINT="$oe"

        local ce=$(jq -r '.CloudEndpoint // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$ce" ] && POWERAI_CLOUD_ENDPOINT="$ce"

        local ck=$(jq -r '.CloudApiKey // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$ck" ] && POWERAI_CLOUD_API_KEY="$ck"

        local cm=$(jq -r '.CloudModel // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$cm" ] && POWERAI_CLOUD_MODEL="$cm"

        local to=$(jq -r '.TimeoutSeconds // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$to" ] && POWERAI_TIMEOUT="$to"

        local as=$(jq -r '.AutoSuggestOnErrors // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$as" ] && POWERAI_AUTO_SUGGEST="$as"

        local lang=$(jq -r '.Language // empty' "$POWERAI_CONFIG_FILE" 2>/dev/null)
        [ -n "$lang" ] && POWERAI_LANGUAGE="$lang"
    fi
}

_powerai_spinner() {
    local is_error="$1"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local grays=(
        "\033[38;5;239m"
        "\033[38;5;242m"
        "\033[38;5;245m"
        "\033[38;5;248m"
        "\033[38;5;252m"
        "\033[38;5;255m"
        "\033[38;5;252m"
        "\033[38;5;248m"
        "\033[38;5;245m"
        "\033[38;5;242m"
    )
    local n_frames=${#frames[@]}
    local n_grays=${#grays[@]}
    local i=0

    # Localized labels
    local lbl_thinking="pensando"
    local lbl_env="analisando ambiente"
    local lbl_model="consultando modelo"
    local lbl_synth="sintetizando comando"
    local lbl_err="analisando erro"

    if [[ "$POWERAI_LANGUAGE" =~ ^en ]]; then
        lbl_thinking="thinking"
        lbl_env="analyzing environment"
        lbl_model="querying model"
        lbl_synth="synthesizing command"
        lbl_err="analyzing error"
    elif [[ "$POWERAI_LANGUAGE" =~ ^es ]]; then
        lbl_thinking="pensando"
        lbl_env="analizando entorno"
        lbl_model="consultando modelo"
        lbl_synth="sintetizando comando"
        lbl_err="analizando error"
    fi

    # Hide cursor
    tput civis 2>/dev/null || printf "\033[?25l"

    while true; do
        local f_idx=$(( (i % n_frames) + 1 ))
        local c_idx=$(( (i % n_grays) + 1 ))
        local frame="${frames[$f_idx]}"
        local color="${grays[$c_idx]}"

        local sub="$lbl_env"
        if [ "$is_error" = "true" ]; then
            sub="$lbl_err"
        elif [ $i -gt 25 ]; then
            sub="$lbl_synth"
        elif [ $i -gt 10 ]; then
            sub="$lbl_model"
        fi

        printf "\r  ${color}${frame}\033[0m  \033[38;5;245m%s\033[0m \033[38;5;238m·\033[0m \033[38;5;241m%s\033[0m\033[K" "$lbl_thinking" "$sub"
        sleep 0.08
        ((i++))
    done
}

_powerai_start_spinner() {
    local is_err="${1:-false}"
    _powerai_stop_spinner
    _powerai_spinner "$is_err" &
    POWERAI_SPINNER_PID=$!
}

_powerai_stop_spinner() {
    if [ -n "$POWERAI_SPINNER_PID" ]; then
        kill "$POWERAI_SPINNER_PID" 2>/dev/null
        wait "$POWERAI_SPINNER_PID" 2>/dev/null
        POWERAI_SPINNER_PID=""
    fi
    tput cnorm 2>/dev/null || printf "\033[?25h"
    printf "\r\033[2K"
}

_powerai_check_local_openai() {
    local endpoint="${POWERAI_LOCAL_ENDPOINT%/}"
    local auth_opt=()
    if [ -n "$POWERAI_LOCAL_API_KEY" ]; then
        auth_opt=(-H "Authorization: Bearer $POWERAI_LOCAL_API_KEY")
    fi
    curl -s --max-time 2 "${auth_opt[@]}" "$endpoint/models" >/dev/null 2>&1
}

_powerai_check_ollama() {
    local endpoint="${POWERAI_OLLAMA_ENDPOINT%/}"
    curl -s --max-time 2 "$endpoint/api/tags" >/dev/null 2>&1
}

_powerai_confirm() {
    local prompt_msg="$1"
    local reply=""
    if [ ! -t 0 ]; then
        read -r reply 2>/dev/null || reply="s"
    elif [ -n "$ZSH_VERSION" ]; then
        printf "%b" "$prompt_msg"
        read -k 1 reply
        echo ""
    else
        printf "%b" "$prompt_msg"
        read -n 1 -r reply
        echo ""
    fi
    if [[ "$reply" =~ ^[SsYy]$ ]] || [ -z "$reply" ]; then
        return 0
    else
        return 1
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
    local turn_count=1
    for item in "${POWERAI_SESSION_MEMORY[@]}"; do
        session_history="$session_history\n[Turn $turn_count]\n$item\n"
        ((turn_count++))
    done

    cat <<EOF
=== SYSTEM & ENVIRONMENT CONTEXT ===
- Current Working Directory (CWD): $cwd
- Operating System: $os_name
- User: $USER (Home: $HOME)
- Active Git Branch: ${git_branch:-N/A}
- Subdirectories: $top_dirs
- Key Files: $top_files

=== RECENT SESSION HISTORY (COMMANDS, QUERIES & TERMINAL OUTPUT) ===
${session_history:-No prior commands in this session.}
EOF
}

_powerai_parse_response() {
    local raw="$1"
    local content=""

    # 1. Unpack outer API message content (Ollama / OpenAI)
    if command -v jq >/dev/null 2>&1; then
        content=$(echo "$raw" | jq -r '.message.content // .choices[0].message.content // empty' 2>/dev/null)
    fi
    [ -z "$content" ] && content="$raw"

    local cmd=""
    local exp=""

    # 2. Parse direct JSON or inside markdown codeblock via jq
    if command -v jq >/dev/null 2>&1; then
        if echo "$content" | jq -e 'type == "object" and (.suggested_command != null or .explanation != null)' >/dev/null 2>&1; then
            cmd=$(echo "$content" | jq -r '.suggested_command // empty' 2>/dev/null)
            exp=$(echo "$content" | jq -r '.explanation // empty' 2>/dev/null)
        fi

        if [ -z "$cmd" ] && [ -z "$exp" ]; then
            local clean_json=$(echo "$content" | sed -n '/```/,/```/p' | sed '/```/d')
            if [ -n "$clean_json" ] && echo "$clean_json" | jq -e 'type == "object"' >/dev/null 2>&1; then
                cmd=$(echo "$clean_json" | jq -r '.suggested_command // empty' 2>/dev/null)
                exp=$(echo "$clean_json" | jq -r '.explanation // empty' 2>/dev/null)
            fi
        fi
    fi

    # 3. Native Regex Fallback
    if [ -z "$cmd" ] && [ -z "$exp" ]; then
        cmd=$(echo "$content" | grep -o '"suggested_command"[^,}]*' | head -n 1 | sed -E 's/.*:[[:space:]]*"?([^",}]+)"?.*/\1/')
        exp=$(echo "$content" | grep -o '"explanation"[^,}]*' | head -n 1 | sed -E 's/.*:[[:space:]]*"?([^",}]+)"?.*/\1/')
    fi

    # 4. Raw Codeblock fallback
    if [ -z "$cmd" ]; then
        local raw_cmd=$(echo "$content" | sed -n '/```/,/```/p' | sed '/```/d' | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*{' | head -n 1)
        [ -n "$raw_cmd" ] && cmd="$raw_cmd"
    fi

    [ "$cmd" = "null" ] || [ "$cmd" = "None" ] || [ "$cmd" = "undefined" ] && cmd=""
    [ "$exp" = "null" ] || [ "$exp" = "None" ] || [ "$exp" = "undefined" ] && exp=""

    echo -e "${cmd}\t${exp}"
}

_powerai_query() {
    local user_prompt="$1"
    local is_error="$2"
    _powerai_load_config

    if [ "$is_error" = "true" ] && [ "$POWERAI_AUTO_SUGGEST" = "false" ]; then
        return 0
    fi

    local use_local_openai=false
    local use_ollama=false
    local use_cloud=false

    if [ "$POWERAI_MODE" = "Local" ]; then
        if [ "$POWERAI_LOCAL_TYPE" = "OpenAICompatible" ]; then
            use_local_openai=true
        elif [ "$POWERAI_LOCAL_TYPE" = "Ollama" ]; then
            use_ollama=true
        else
            if _powerai_check_ollama; then
                use_ollama=true
            elif _powerai_check_local_openai; then
                use_local_openai=true
            else
                use_ollama=true
            fi
        fi
    elif [ "$POWERAI_MODE" = "Cloud" ]; then
        use_cloud=true
    else
        # Auto Mode: check Ollama first, then Local OpenAI, then Cloud
        if _powerai_check_ollama; then
            use_ollama=true
        elif _powerai_check_local_openai; then
            use_local_openai=true
        elif [ -n "$POWERAI_CLOUD_API_KEY" ]; then
            use_cloud=true
        else
            echo ""
            echo "  [PowerAI] No AI provider available:"
            echo "  1. Local Ollama: Start Ollama at $POWERAI_OLLAMA_ENDPOINT ('ollama run $POWERAI_LOCAL_MODEL')"
            echo "  2. Local OpenAI-Compatible: Verify server running at $POWERAI_LOCAL_ENDPOINT"
            echo "  3. Cloud (OpenAI): Set 'CloudApiKey' in ~/.powerai/config.json or export OPENAI_API_KEY='your-key'"
            echo ""
            return 1
        fi
    fi

    # Iniciar animacao de pensamento
    _powerai_start_spinner "$is_error"

    local harness_ctx="$(_powerai_get_context)"
    local sys_prompt=""

    if [[ "$POWERAI_LANGUAGE" =~ ^en ]]; then
        sys_prompt="You are PowerAI, an expert terminal assistant and CLI copilot for macOS and Linux (Bash/Zsh).
$harness_ctx

RULES:
1. TYPOS & UNKNOWN COMMANDS (e.g. 'mrdir kilo' -> 'mkdir kilo', 'dockr ps' -> 'docker ps', 'gti status' -> 'git status'):
   - Identify the intended valid shell command.
   - Return the corrected command in 'suggested_command'.
   - Return a concise English explanation in 'explanation'.

2. NATURAL LANGUAGE ACTIONS & QUESTIONS (e.g. 'how to see my ip', 'list open ports', 'show memory usage'):
   - Translate the user intent into the complete, functional macOS/Linux command (e.g. 'ipconfig getifaddr en0' or 'ifconfig | grep inet').
   - Return the command in 'suggested_command'.
   - Return a concise English explanation in 'explanation'.

3. OUTPUT MEMORY & INFORMATIONAL INQUIRIES:
   - If the user asks about data already printed in Terminal Output history, answer directly in 'explanation' and set 'suggested_command' to \"\".

OUTPUT FORMAT:
Respond ONLY with a valid JSON object:
{\"suggested_command\": \"...\", \"explanation\": \"...\"}"
    elif [[ "$POWERAI_LANGUAGE" =~ ^es ]]; then
        sys_prompt="Eres PowerAI, un copiloto experto en terminal para macOS y Linux (Bash/Zsh).
$harness_ctx

REGLAS:
1. ERRORES DE ESCRITURA Y COMANDOS DESCONOCIDOS (ej: 'mrdir kilo' -> 'mkdir kilo', 'dockr ps' -> 'docker ps', 'gti' -> 'git'):
   - Identifica el comando válido previsto.
   - Devuelve el comando corregido en 'suggested_command'.
   - Escribe una breve explicación en español en 'explanation'.

2. PREGUNTAS Y ACCIONES EN LENGUAJE NATURAL (ej: 'como ver mi ip', 'listar archivos', 'ver puertos abiertos'):
   - Traduce la intención al comando funcional exacto para macOS/Linux (ej: 'ipconfig getifaddr en0' o 'ifconfig | grep inet').
   - Devuelve el comando en 'suggested_command'.
   - Escribe una breve explicación en español en 'explanation'.

3. MEMORIA DE SALIDA Y CONSULTAS INFORMATIVAS:
   - Si el usuario pregunta sobre datos ya impresos en el historial de salida, responde directamente en 'explanation' y deja 'suggested_command' como \"\".

FORMATO DE SALIDA:
Responde ÚNICAMENTE con un objeto JSON válido:
{\"suggested_command\": \"...\", \"explanation\": \"...\"}"
    else
        # Portuguese (pt-BR default)
        sys_prompt="Você é o PowerAI, um copiloto especialista em terminal para macOS e Linux (Bash/Zsh).
$harness_ctx

REGRAS:
1. ERROS DE DIGITAÇÃO E COMANDOS NÃO ENCONTRADOS (ex: 'mrdir kilo' -> 'mkdir kilo', 'dockr ps' -> 'docker ps', 'gti' -> 'git'):
   - Identifique o comando shell correto pretendido.
   - Coloque o comando corrigido em 'suggested_command'.
   - Escreva uma explicação curta em português em 'explanation'.

2. PERGUNTAS E PEDIDOS EM LINGUAGEM NATURAL (ex: 'como ver meu ip', 'listar arquivos', 'ver portas abertas'):
   - Traduza a intenção para o comando funcional exato para macOS/Linux (ex: 'ipconfig getifaddr en0' ou 'ifconfig | grep inet').
   - Coloque o comando em 'suggested_command'.
   - Escreva uma explicação curta em português em 'explanation'.

3. MEMÓRIA DE SAÍDA E DADOS DA TELA:
   - Se o usuário perguntar sobre dados já impressos no histórico do terminal, responda diretamente em 'explanation' e deixe 'suggested_command' vazio (\"\").

FORMATO DE SAÍDA:
Responda APENAS com um objeto JSON válido:
{\"suggested_command\": \"...\", \"explanation\": \"...\"}"
    fi

    local response=""

    if [ "$use_ollama" = true ]; then
        local json_payload=$(jq -n \
            --arg model "$POWERAI_LOCAL_MODEL" \
            --arg sys "$sys_prompt" \
            --arg user "$user_prompt" \
            '{
                model: $model,
                stream: false,
                options: { temperature: 0.0 },
                messages: [
                    { role: "system", content: $sys },
                    { role: "user", content: $user }
                ]
            }')

        response=$(curl -s -X POST "$POWERAI_OLLAMA_ENDPOINT/api/chat" \
            -H "Content-Type: application/json" \
            -d "$json_payload" \
            --max-time "$POWERAI_TIMEOUT")
    elif [ "$use_local_openai" = true ]; then
        local local_base="${POWERAI_LOCAL_ENDPOINT%/}"
        local local_url="$local_base/chat/completions"
        [[ "$local_base" == *"/chat/completions" ]] && local_url="$local_base"

        local json_payload=$(jq -n \
            --arg model "$POWERAI_LOCAL_MODEL" \
            --arg sys "$sys_prompt" \
            --arg user "$user_prompt" \
            '{
                model: $model,
                temperature: 0.0,
                messages: [
                    { role: "system", content: $sys },
                    { role: "user", content: $user }
                ]
            }')

        local auth_opt=()
        if [ -n "$POWERAI_LOCAL_API_KEY" ]; then
            auth_opt=(-H "Authorization: Bearer $POWERAI_LOCAL_API_KEY")
        fi

        response=$(curl -s -X POST "$local_url" \
            -H "Content-Type: application/json" \
            "${auth_opt[@]}" \
            -d "$json_payload" \
            --max-time "$POWERAI_TIMEOUT")
    else
        local cloud_url="${POWERAI_CLOUD_ENDPOINT%/}/chat/completions"
        local json_payload=$(jq -n \
            --arg model "$POWERAI_CLOUD_MODEL" \
            --arg sys "$sys_prompt" \
            --arg user "$user_prompt" \
            '{
                model: $model,
                temperature: 0.0,
                messages: [
                    { role: "system", content: $sys },
                    { role: "user", content: $user }
                ]
            }')

        response=$(curl -s -X POST "$cloud_url" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $POWERAI_CLOUD_API_KEY" \
            -d "$json_payload" \
            --max-time "$POWERAI_TIMEOUT")
    fi

    # Parar o spinner e limpar a linha
    _powerai_stop_spinner

    if [ -z "$response" ]; then
        echo -e "  \033[38;5;240m[Error] Failed to connect to AI provider (empty response or timeout).\033[0m"
        return 1
    fi

    # Extract JSON fields via native JQ/POSIX parser (Zero Python)
    local parsed=$(_powerai_parse_response "$response")
    local cmd=$(echo "$parsed" | cut -f1)
    local exp=$(echo "$parsed" | cut -f2)

    if [ -z "$cmd" ] && [ -z "$exp" ]; then
        echo "$response"
        return 0
    fi

    # Verificar se o comando sugerido apenas repete o comando anterior
    local is_repeat=false
    if [ ${#POWERAI_SESSION_MEMORY[@]} -gt 0 ]; then
        local last_turn="${POWERAI_SESSION_MEMORY[-1]}"
        [ -z "$last_turn" ] && last_turn="${POWERAI_SESSION_MEMORY[${#POWERAI_SESSION_MEMORY[@]}]}"
        if [[ "$last_turn" == *"Command: $cmd"* ]]; then
            is_repeat=true
        fi
    fi

    if [ "$is_repeat" = "true" ] || [ -z "$cmd" ] || [ "$cmd" = "null" ]; then
        if [ -n "$exp" ]; then
            echo ""
            echo -e "  \033[1;37m✦\033[0m \033[38;5;252m$exp\033[0m"
            echo ""
            _powerai_add_session "$user_prompt" "" "$exp"
            return 0
        fi
    fi

    # Localized prompt strings
    local lbl_confirm="  \033[38;5;242mExecutar comando? \033[38;5;248m[Enter/S = Sim | Esc/N = Não]:\033[0m "
    local lbl_exec="[Executando]"
    local lbl_cancel="Cancelado."

    if [[ "$POWERAI_LANGUAGE" =~ ^en ]]; then
        lbl_confirm="  \033[38;5;242mExecute command? \033[38;5;248m[Enter/Y = Yes | Esc/N = No]:\033[0m "
        lbl_exec="[Executing]"
        lbl_cancel="Canceled."
    elif [[ "$POWERAI_LANGUAGE" =~ ^es ]]; then
        lbl_confirm="  \033[38;5;242m¿Ejecutar comando? \033[38;5;248m[Enter/S = Sí | Esc/N = No]:\033[0m "
        lbl_exec="[Ejecutando]"
        lbl_cancel="Cancelado."
    fi

    if [ -n "$cmd" ] && [ "$cmd" != "null" ]; then
        echo ""
        echo -e "  \033[1;37m✦ $cmd\033[0m"
        if [ -n "$exp" ]; then
            echo -e "    \033[38;5;244m↳ $exp\033[0m"
        fi
        echo ""
        if _powerai_confirm "$lbl_confirm"; then
            echo -e "  \033[38;5;250m$lbl_exec $cmd\033[0m"
            echo ""

            local cmd_output=""
            if [[ "$cmd" =~ ^[[:space:]]*cd([[:space:]]|$) ]] || [[ "$cmd" =~ ^[[:space:]]*export([[:space:]]|$) ]] || [[ "$cmd" =~ ^[[:space:]]*source([[:space:]]|$) ]]; then
                eval "$cmd"
                cmd_output="Working directory changed to: $PWD"
            else
                local tmp_out=$(mktemp /tmp/powerai_out.XXXXXX 2>/dev/null || mktemp 2>/dev/null || echo "/tmp/powerai_cmd_$$.log")
                eval "$cmd" 2>&1 | tee "$tmp_out"
                cmd_output=$(cat "$tmp_out" 2>/dev/null)
                rm -f "$tmp_out"
            fi

            _powerai_add_session "$user_prompt" "$cmd" "$cmd_output"
        else
            echo -e "  \033[38;5;240m$lbl_cancel\033[0m"
        fi
    elif [ -n "$exp" ]; then
        echo ""
        echo -e "  \033[1;37m✦\033[0m \033[38;5;252m$exp\033[0m"
        echo ""
        _powerai_add_session "$user_prompt" "" "$exp"
    fi
}

_powerai_ai_entry() {
    if [ "$1" = "uninstall" ] || [ "$1" = "--uninstall" ] || [ "$1" = "desinstalar" ]; then
        echo "=========================================================="
        echo " [PowerAI] Uninstall Confirmation"
        echo "=========================================================="
        if _powerai_confirm "Do you want to uninstall PowerAI from your system? [Enter/Y = Yes | Esc/N = No]: "; then
            if [ -f "$POWERAI_CONFIG_DIR/uninstall.sh" ]; then
                bash "$POWERAI_CONFIG_DIR/uninstall.sh"
            else
                curl -fsSL "https://raw.githubusercontent.com/Luizhcrs/powerai/main/uninstall.sh" | bash
            fi
        else
            echo "Uninstallation canceled."
        fi
        return 0
    fi

    if [ "$1" = "version" ] || [ "$1" = "-v" ] || [ "$1" = "--version" ] || [ "$1" = "versao" ]; then
        _powerai_check_update false
        return 0
    fi

    if [ "$1" = "update" ] || [ "$1" = "upgrade" ] || [ "$1" = "atualizar" ]; then
        _powerai_self_update
        return 0
    fi

    if [ "$1" = "language" ] || [ "$1" = "lang" ] || [ "$1" = "idioma" ]; then
        local new_lang="$2"
        if [ "$new_lang" = "pt" ] || [ "$new_lang" = "pt-BR" ] || [ "$new_lang" = "pt_BR" ]; then
            new_lang="pt-BR"
        elif [ "$new_lang" = "en" ] || [ "$new_lang" = "en-US" ] || [ "$new_lang" = "en_US" ]; then
            new_lang="en-US"
        elif [ "$new_lang" = "es" ] || [ "$new_lang" = "es-ES" ] || [ "$new_lang" = "es_ES" ]; then
            new_lang="es-ES"
        else
            echo "Usage: ai language <pt | en | es>"
            return 0
        fi

        if [ -f "$POWERAI_CONFIG_FILE" ]; then
            local tmp_cfg=$(mktemp)
            jq --arg l "$new_lang" '.Language = $l' "$POWERAI_CONFIG_FILE" > "$tmp_cfg" && mv "$tmp_cfg" "$POWERAI_CONFIG_FILE"
            POWERAI_LANGUAGE="$new_lang"
            echo "  ✓ Idioma alterado para: $new_lang"
        fi
        return 0
    fi

    if [ "$1" = "config" ]; then
        _powerai_load_config
        echo "=== PowerAI Active Configuration ==="
        echo "Version: $POWERAI_VERSION"
        echo "Config File: $POWERAI_CONFIG_FILE"
        echo "Language: $POWERAI_LANGUAGE"
        echo "Mode: $POWERAI_MODE"
        echo "Local Type: $POWERAI_LOCAL_TYPE"
        echo "Local Endpoint: $POWERAI_LOCAL_ENDPOINT"
        echo "Local API Key: $([ -n "$POWERAI_LOCAL_API_KEY" ] && echo "***configured***" || echo "not configured")"
        echo "Local Model: $POWERAI_LOCAL_MODEL"
        echo "Ollama Endpoint: $POWERAI_OLLAMA_ENDPOINT"
        echo "Cloud Endpoint: $POWERAI_CLOUD_ENDPOINT"
        echo "Cloud Model: $POWERAI_CLOUD_MODEL"
        echo "Cloud API Key: $([ -n "$POWERAI_CLOUD_API_KEY" ] && echo "***configured***" || echo "not configured")"
        echo "Auto-Suggest on Errors: $POWERAI_AUTO_SUGGEST"
        return 0
    fi

    if [ $# -eq 0 ]; then
        echo "  [PowerAI] Invisible Cognitive Terminal Layer ($POWERAI_VERSION)"
        echo "  Usage: ai <query or natural language request>"
        echo "         ? <query>"
        echo "         ai update (update to latest release)"
        echo "         ai version (check current & remote version)"
        echo "         ai language <pt|en|es> (change language)"
        echo "         ai config (view active settings)"
        echo "         ai uninstall (remove PowerAI)"
        return 0
    fi
    local query="$*"
    _powerai_query "$query" false
}

ai() {
    _powerai_ai_entry "$@"
}

# Zsh: disable wildcard globbing errors for '?' and attach noglob to ai / ? aliases
if [ -n "$ZSH_VERSION" ]; then
    setopt nonomatch 2>/dev/null || true
    alias ai='noglob _powerai_ai_entry'
    alias '?'='noglob _powerai_ai_entry'
else
    alias '?'='ai'
fi

# --- AUTOMATIC UNKNOWN COMMAND INTERCEPTOR (BASH & ZSH) ---

# Para o Bash: command_not_found_handle
command_not_found_handle() {
    local failed_cmd="$*"
    _powerai_load_config
    if [ "$POWERAI_AUTO_SUGGEST" = true ] || [ "$POWERAI_AUTO_SUGGEST" = "true" ]; then
        echo "bash: $1: comando não encontrado" >&2
        _powerai_query "$failed_cmd" true
    else
        echo "bash: $1: comando não encontrado" >&2
    fi
    return 127
}

# Para o Zsh: command_not_found_handler
command_not_found_handler() {
    local failed_cmd="$*"
    _powerai_load_config
    if [ "$POWERAI_AUTO_SUGGEST" = true ] || [ "$POWERAI_AUTO_SUGGEST" = "true" ]; then
        echo "zsh: comando não encontrado: $1" >&2
        _powerai_query "$failed_cmd" true
    else
        echo "zsh: comando não encontrado: $1" >&2
    fi
    return 127
}
