#!/usr/bin/env bash
# install.sh - Modern & Interactive Installer for PowerAI (Linux & macOS)
# Usage: curl -fsSL https://raw.githubusercontent.com/Luizhcrs/nuno/main/install.sh | bash
#        or ./install.sh [--quick]

set -e

_read_line() {
    local prompt_text="$1"
    local default_val="$2"
    local user_val=""

    if [ -e /dev/tty ]; then
        printf "%b" "$prompt_text" > /dev/tty
        read -r user_val < /dev/tty || user_val=""
    else
        printf "%b" "$prompt_text"
        read -r user_val || user_val=""
    fi

    if [ -z "$user_val" ]; then
        echo "$default_val"
    else
        echo "$user_val"
    fi
}

_select_menu() {
    local out_var="$1"
    local step_title="$2"
    shift 2
    local options=("$@")
    local count=${#options[@]}
    local selected=0

    # Non-interactive fallback
    if [ ! -t 0 ] && [ ! -e /dev/tty ]; then
        eval "$out_var=0"
        return 0
    fi

    # Hide cursor
    tput civis 2>/dev/null || printf "\033[?25l"

    # Save original stty settings and set raw single-key mode
    local old_stty=""
    if [ -e /dev/tty ]; then
        old_stty=$(stty -g < /dev/tty 2>/dev/null || true)
        stty -echo -icanon min 1 time 0 < /dev/tty 2>/dev/null || stty -echo 2>/dev/null || true
    elif [ -t 0 ]; then
        old_stty=$(stty -g 2>/dev/null || true)
        stty -echo -icanon min 1 time 0 2>/dev/null || stty -echo 2>/dev/null || true
    fi

    _cleanup_menu() {
        if [ -n "$old_stty" ]; then
            if [ -e /dev/tty ]; then
                stty "$old_stty" < /dev/tty 2>/dev/null || stty sane < /dev/tty 2>/dev/null || true
            else
                stty "$old_stty" 2>/dev/null || stty sane 2>/dev/null || true
            fi
        fi
        tput cnorm 2>/dev/null || printf "\033[?25h"
    }

    # Print step title header
    printf "  \033[38;5;248m%s\033[0m \033[38;5;240m(Navegue com ↑/↓ e Enter)\033[0m\n" "$step_title"

    while true; do
        # Render options
        local idx=0
        for opt in "${options[@]}"; do
            if [ "$idx" -eq "$selected" ]; then
                # Selected: Soft dark-gray background pill + bright white text + arrow
                printf "     \033[1;37;48;5;236m ▸ %-62s \033[0m\033[K\n" "$opt"
            else
                # Unselected: clean subtle gray
                printf "     \033[38;5;244m   %-62s \033[0m\033[K\n" "$opt"
            fi
            idx=$((idx + 1))
        done

        # Read 1 char from /dev/tty
        local c1="" c2="" c3=""
        if [ -e /dev/tty ]; then
            c1=$(dd bs=1 count=1 < /dev/tty 2>/dev/null || true)
        else
            c1=$(dd bs=1 count=1 2>/dev/null || true)
        fi

        if [ "$c1" = $'\x1b' ]; then
            # Read escape sequence
            if [ -e /dev/tty ]; then
                c2=$(dd bs=1 count=1 < /dev/tty 2>/dev/null || true)
                if [ "$c2" = "[" ]; then
                    c3=$(dd bs=1 count=1 < /dev/tty 2>/dev/null || true)
                fi
            else
                c2=$(dd bs=1 count=1 2>/dev/null || true)
                if [ "$c2" = "[" ]; then
                    c3=$(dd bs=1 count=1 2>/dev/null || true)
                fi
            fi

            if [ "$c3" = "A" ]; then
                # UP
                if [ $selected -gt 0 ]; then
                    selected=$((selected - 1))
                else
                    selected=$((count - 1))
                fi
            elif [ "$c3" = "B" ]; then
                # DOWN
                if [ $selected -lt $((count - 1)) ]; then
                    selected=$((selected + 1))
                else
                    selected=0
                fi
            fi
        elif [ "$c1" = "k" ] || [ "$c1" = "K" ]; then
            if [ $selected -gt 0 ]; then
                selected=$((selected - 1))
            else
                selected=$((count - 1))
            fi
        elif [ "$c1" = "j" ] || [ "$c1" = "J" ]; then
            if [ $selected -lt $((count - 1)) ]; then
                selected=$((selected + 1))
            else
                selected=0
            fi
        elif [ "$c1" = "1" ]; then
            selected=0
            break
        elif [ "$c1" = "2" ] && [ $count -gt 1 ]; then
            selected=1
            break
        elif [ "$c1" = "3" ] && [ $count -gt 2 ]; then
            selected=2
            break
        elif [ "$c1" = "4" ] && [ $count -gt 3 ]; then
            selected=3
            break
        elif [ "$c1" = "" ] || [ "$c1" = $'\n' ] || [ "$c1" = $'\r' ]; then
            break
        elif [ "$c1" = $'\x03' ]; then # Ctrl+C
            _cleanup_menu
            echo ""
            echo "Instalação cancelada."
            exit 130
        fi

        # Move cursor back up to redraw menu in place
        printf "\033[%dA" "$count"
    done

    _cleanup_menu

    # Dynamic in-place collapse: clear the menu options and replace with single completed line
    printf "\033[%dA\033[J" "$((count + 1))"
    local raw_chosen="${options[$selected]}"
    # Extract clean display name (strip leading number prefix)
    local clean_name=$(echo "$raw_chosen" | sed -E 's/^[0-9]+\)[[:space:]]*//' | sed -E 's/[[:space:]]*·.*//')
    printf "  \033[1;37m✓\033[0m  \033[38;5;250m%-28s\033[0m \033[1;37m%s\033[0m\n" "$step_title" "$clean_name"

    eval "$out_var=$selected"
}

_spin_step() {
    local msg="$1"
    local cmd="$2"
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local grays=("\033[38;5;240m" "\033[38;5;244m" "\033[38;5;248m" "\033[38;5;252m" "\033[38;5;255m" "\033[38;5;252m" "\033[38;5;248m" "\033[38;5;244m")
    
    tput civis 2>/dev/null || printf "\033[?25l"
    
    eval "$cmd" >/dev/null 2>&1 &
    local pid=$!
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        local f_idx=$(( (i % 10) + 1 ))
        local c_idx=$(( (i % 8) + 1 ))
        local frame="${frames[$f_idx]}"
        local color="${grays[$c_idx]}"
        printf "\r  ${color}${frame}\033[0m  \033[38;5;245m%s\033[0m\033[K" "$msg"
        sleep 0.06
        ((i++))
    done
    wait "$pid" 2>/dev/null || true
    
    tput cnorm 2>/dev/null || printf "\033[?25h"
    printf "\r\033[2K  \033[1;37m✓\033[0m  \033[38;5;250m%s\033[0m\n" "$msg"
}

# --- HEADER / BANNER ---
clear 2>/dev/null || true
echo ""
echo -e "  \033[1;37m✦  P O W E R A I\033[0m"
echo -e "     \033[38;5;244mCamada Cognitiva & Copiloto para Terminal\033[0m"
echo -e "     \033[38;5;238m─────────────────────────────────────────────────────────────\033[0m"
echo ""

# Quick mode check
QUICK_MODE=false
if [ "$1" = "--quick" ] || [ "$1" = "-y" ] || [ "$1" = "--yes" ]; then
    QUICK_MODE=true
fi

# Step 1: Detect Dependencies
_spin_step "1. Ambiente & Dependências:  curl, python3, jq detectados" "sleep 0.3"

OLLAMA_INSTALLED=false
if command -v ollama >/dev/null 2>&1; then
    OLLAMA_INSTALLED=true
fi

# Defaults
CHOSEN_MODE="Auto"
CHOSEN_LOCAL_TYPE="Ollama"
CHOSEN_LOCAL_ENDPOINT="http://127.0.0.1:5151/v1"
CHOSEN_LOCAL_API_KEY=""
CHOSEN_LOCAL_MODEL="qwen2.5-coder:1.5b"
CHOSEN_OLLAMA_ENDPOINT="http://localhost:11434"
CHOSEN_CLOUD_ENDPOINT="https://api.openai.com/v1"
CHOSEN_CLOUD_API_KEY="${OPENAI_API_KEY:-}"
CHOSEN_CLOUD_MODEL="gpt-4o-mini"
CHOSEN_AUTO_SUGGEST=true

if [ "$QUICK_MODE" = false ]; then
    menu_providers=(
        "1) Ollama Local     · Recomendado: ultrarrápido, offline, <1s"
        "2) API Local        · OMLX, LM Studio, vLLM em :5151 / :8000"
        "3) Nuvem            · OpenAI gpt-4o-mini / Groq / OpenRouter"
        "4) Automático       · Detecta localmente e faz fallback nuvem"
    )

    CHOSEN_PROV_IDX=0
    _select_menu CHOSEN_PROV_IDX "2. Provedor de IA:" "${menu_providers[@]}"

    case "$CHOSEN_PROV_IDX" in
        1)
            CHOSEN_MODE="Local"
            CHOSEN_LOCAL_TYPE="OpenAICompatible"
            menu_local_models=(
                "1) qwen2.5-coder:1.5b                       · Mais leve (<1s)"
                "2) mlx-community--Qwen2.5-7B-Instruct-4bit  · Alta capacidade"
                "3) Personalizado                            · Digitar manualmente"
            )
            CHOSEN_LM_IDX=0
            _select_menu CHOSEN_LM_IDX "3. Modelo da API Local:" "${menu_local_models[@]}"
            case "$CHOSEN_LM_IDX" in
                0) CHOSEN_LOCAL_MODEL="qwen2.5-coder:1.5b" ;;
                1) CHOSEN_LOCAL_MODEL="mlx-community--Qwen2.5-7B-Instruct-4bit" ;;
                *) CHOSEN_LOCAL_MODEL=$(_read_line "     Nome do modelo: " "qwen2.5-coder:1.5b") ;;
            esac
            CHOSEN_LOCAL_ENDPOINT=$(_read_line "     Endpoint [Padrão: http://127.0.0.1:5151/v1]: " "http://127.0.0.1:5151/v1")
            CHOSEN_LOCAL_API_KEY=$(_read_line "     API Key (opcional se não exigir): " "")
            ;;
        2)
            CHOSEN_MODE="Cloud"
            menu_cloud_models=(
                "1) gpt-4o-mini               · Recomendado (Rápido e econômico)"
                "2) gpt-4o                    · Modelo completo de alta inteligência"
                "3) llama-3.3-70b-versatile   · Groq Cloud ultrarrápido"
                "4) Personalizado             · Digitar outro nome de modelo"
            )
            CHOSEN_CM_IDX=0
            _select_menu CHOSEN_CM_IDX "3. Modelo de Nuvem:" "${menu_cloud_models[@]}"
            case "$CHOSEN_CM_IDX" in
                0) CHOSEN_CLOUD_MODEL="gpt-4o-mini" ;;
                1) CHOSEN_CLOUD_MODEL="gpt-4o" ;;
                2) CHOSEN_CLOUD_MODEL="llama-3.3-70b-versatile" ;;
                *) CHOSEN_CLOUD_MODEL=$(_read_line "     Nome do modelo: " "gpt-4o-mini") ;;
            esac
            CHOSEN_CLOUD_API_KEY=$(_read_line "     OpenAI / Groq API Key: " "${OPENAI_API_KEY:-}")
            ;;
        3)
            CHOSEN_MODE="Auto"
            CHOSEN_LOCAL_TYPE="Ollama"
            ;;
        *)
            CHOSEN_MODE="Auto"
            CHOSEN_LOCAL_TYPE="Ollama"
            menu_ollama_models=(
                "1) qwen2.5-coder:1.5b  · Recomendado (Ultraleve, <1s, Apple Metal GPU)"
                "2) qwen2.5-coder:7b    · Mais inteligente (Requer ~5GB de RAM)"
                "3) deepseek-coder:1.3b · Alternativa compacta e rápida"
                "4) Personalizado       · Digitar outro nome de modelo"
            )
            CHOSEN_OM_IDX=0
            _select_menu CHOSEN_OM_IDX "3. Modelo Ollama:" "${menu_ollama_models[@]}"
            case "$CHOSEN_OM_IDX" in
                0) CHOSEN_LOCAL_MODEL="qwen2.5-coder:1.5b" ;;
                1) CHOSEN_LOCAL_MODEL="qwen2.5-coder:7b" ;;
                2) CHOSEN_LOCAL_MODEL="deepseek-coder:1.3b" ;;
                *) CHOSEN_LOCAL_MODEL=$(_read_line "     Nome do modelo Ollama: " "qwen2.5-coder:1.5b") ;;
            esac

            # Offer model download if Ollama is available
            if [ "$OLLAMA_INSTALLED" = true ]; then
                if ! ollama list 2>/dev/null | grep -q "$CHOSEN_LOCAL_MODEL"; then
                    menu_dl=(
                        "1) Sim, baixar agora via ollama pull"
                        "2) Não, vou baixar manualmente mais tarde"
                    )
                    CHOSEN_DL_IDX=0
                    _select_menu CHOSEN_DL_IDX "Baixar modelo agora?" "${menu_dl[@]}"
                    if [ "$CHOSEN_DL_IDX" -eq 0 ]; then
                        echo ""
                        echo -e "     \033[38;5;244mBaixando modelo no Ollama (aguarde alguns instantes)...\033[0m"
                        ollama pull "$CHOSEN_LOCAL_MODEL" || true
                    fi
                fi
            fi
            ;;
    esac

    menu_features=(
        "1) Sugestões e correções automáticas em erros ativadas (Padrão)"
        "2) Apenas responder a consultas manuais ('ai' ou '?')"
    )
    CHOSEN_FT_IDX=0
    _select_menu CHOSEN_FT_IDX "4. Recursos de Terminal:" "${menu_features[@]}"
    if [ "$CHOSEN_FT_IDX" -eq 1 ]; then
        CHOSEN_AUTO_SUGGEST=false
    fi
fi

# Step 5: Installation Execution
echo ""
echo -e "  \033[38;5;248m5. Instalando e configurando arquivos:\033[0m"

INSTALL_DIR="$HOME/.powerai"
_spin_step "Criando diretório $INSTALL_DIR..." "mkdir -p '$INSTALL_DIR'"

# Copy or download files
if [ -f "$(dirname "$0")/powerai.sh" ]; then
    _spin_step "Instalando script principal (powerai.sh)..." "cp '$(dirname "$0")/powerai.sh' '$INSTALL_DIR/powerai.sh'"
else
    _spin_step "Baixando script principal (powerai.sh)..." "curl -fsSL 'https://raw.githubusercontent.com/Luizhcrs/nuno/main/powerai.sh' -o '$INSTALL_DIR/powerai.sh'"
fi

if [ -f "$(dirname "$0")/uninstall.sh" ]; then
    _spin_step "Instalando desinstalador (uninstall.sh)..." "cp '$(dirname "$0")/uninstall.sh' '$INSTALL_DIR/uninstall.sh'"
else
    _spin_step "Baixando desinstalador (uninstall.sh)..." "curl -fsSL 'https://raw.githubusercontent.com/Luizhcrs/nuno/main/uninstall.sh' -o '$INSTALL_DIR/uninstall.sh'"
fi

if [ -f "$(dirname "$0")/parse_response.py" ]; then
    _spin_step "Instalando extrator de respostas (parse_response.py)..." "cp '$(dirname "$0")/parse_response.py' '$INSTALL_DIR/parse_response.py'"
else
    _spin_step "Baixando extrator de respostas (parse_response.py)..." "curl -fsSL 'https://raw.githubusercontent.com/Luizhcrs/nuno/main/parse_response.py' -o '$INSTALL_DIR/parse_response.py'"
fi

chmod +x "$INSTALL_DIR/powerai.sh" "$INSTALL_DIR/uninstall.sh" "$INSTALL_DIR/parse_response.py" 2>/dev/null || true

# Write config.json
CONFIG_FILE="$INSTALL_DIR/config.json"
cat <<EOF > "$CONFIG_FILE"
{
  "Mode": "$CHOSEN_MODE",
  "LocalType": "$CHOSEN_LOCAL_TYPE",
  "LocalEndpoint": "$CHOSEN_LOCAL_ENDPOINT",
  "LocalApiKey": "$CHOSEN_LOCAL_API_KEY",
  "LocalModel": "$CHOSEN_LOCAL_MODEL",
  "OllamaEndpoint": "$CHOSEN_OLLAMA_ENDPOINT",
  "CloudEndpoint": "$CHOSEN_CLOUD_ENDPOINT",
  "CloudApiKey": "$CHOSEN_CLOUD_API_KEY",
  "CloudModel": "$CHOSEN_CLOUD_MODEL",
  "AutoSuggestOnErrors": $CHOSEN_AUTO_SUGGEST,
  "AutoHealingRetries": 2,
  "TimeoutSeconds": 25
}
EOF
_spin_step "Gravando configuração personalizada em config.json..." "sleep 0.2"

# Setup profile hooks
SOURCE_LINE="[ -f \"$INSTALL_DIR/powerai.sh\" ] && source \"$INSTALL_DIR/powerai.sh\""

if [ -f "$HOME/.bashrc" ] && ! grep -q "powerai.sh" "$HOME/.bashrc"; then
    echo "$SOURCE_LINE" >> "$HOME/.bashrc"
fi

if [ -f "$HOME/.zshrc" ] && ! grep -q "powerai.sh" "$HOME/.zshrc"; then
    echo "$SOURCE_LINE" >> "$HOME/.zshrc"
fi
_spin_step "Integrando hooks nativos ao ~/.zshrc e ~/.bashrc..." "sleep 0.2"

# Success Card
echo ""
echo -e "  \033[38;5;238m─────────────────────────────────────────────────────────────\033[0m"
echo -e "  \033[1;37m✦  PowerAI instalado com sucesso!\033[0m"
echo ""
echo -e "    \033[38;5;244m• Provedor:\033[0m  \033[1;37m$CHOSEN_MODE ($CHOSEN_LOCAL_MODEL)\033[0m"
echo -e "    \033[38;5;244m• Destino:\033[0m   \033[38;5;250m$INSTALL_DIR\033[0m"
echo -e "    \033[38;5;244m• Config:\033[0m    \033[38;5;250m$CONFIG_FILE\033[0m"
echo ""
echo -e "    \033[38;5;245mPara ativar no terminal atual, execute:\033[0m"
echo -e "      \033[1;37msource ~/.zshrc\033[0m \033[38;5;240m(ou source ~/.bashrc)\033[0m"
echo ""
echo -e "    \033[38;5;245mComandos disponíveis:\033[0m"
echo -e "      \033[38;5;250mai <pergunta>\033[0m      \033[38;5;240m· Consulta em linguagem natural\033[0m"
echo -e "      \033[38;5;250m? <pergunta>\033[0m       \033[38;5;240m· Atalho rápido\033[0m"
echo -e "      \033[38;5;250mai config\033[0m          \033[38;5;240m· Ver configurações ativas\033[0m"
echo -e "      \033[38;5;250mai uninstall\033[0m       \033[38;5;240m· Desinstalação completa\033[0m"
echo -e "  \033[38;5;238m─────────────────────────────────────────────────────────────\033[0m"
echo ""
