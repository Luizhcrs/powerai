#!/usr/bin/env bash
# install.sh - Modern, Multilingual & Self-Healing Installer for PowerAI
# Usage: curl -fsSL https://raw.githubusercontent.com/Luizhcrs/powerai/main/install.sh | bash
#        or ./install.sh [--quick] [--lang=pt|en|es]

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

_detect_os_language() {
    local sys_locale=""
    if [ "$(uname -s)" = "Darwin" ]; then
        sys_locale=$(defaults read -g AppleLocale 2>/dev/null || echo "${LANG:-}")
    else
        sys_locale="${LANG:-${LC_ALL:-${LC_MESSAGES:-}}}"
    fi

    if [[ "$sys_locale" =~ ^pt ]] || [[ "$sys_locale" =~ ^PT ]]; then
        echo "pt-BR"
    elif [[ "$sys_locale" =~ ^es ]] || [[ "$sys_locale" =~ ^ES ]]; then
        echo "es-ES"
    else
        echo "en-US"
    fi
}

_auto_install_pkg() {
    local pkg_name="$1"
    if command -v brew >/dev/null 2>&1; then
        brew install "$pkg_name" >/dev/null 2>&1 || true
    elif command -v apt-get >/dev/null 2>&1; then
        if [ "${EUID:-$(id -u)}" -eq 0 ]; then
            apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq "$pkg_name" >/dev/null 2>&1 || true
        elif command -v sudo >/dev/null 2>&1; then
            sudo apt-get update -qq >/dev/null 2>&1 && sudo apt-get install -y -qq "$pkg_name" >/dev/null 2>&1 || true
        fi
    elif command -v dnf >/dev/null 2>&1; then
        if [ "${EUID:-$(id -u)}" -eq 0 ]; then
            dnf install -y -q "$pkg_name" >/dev/null 2>&1 || true
        elif command -v sudo >/dev/null 2>&1; then
            sudo dnf install -y -q "$pkg_name" >/dev/null 2>&1 || true
        fi
    elif command -v pacman >/dev/null 2>&1; then
        if [ "${EUID:-$(id -u)}" -eq 0 ]; then
            pacman -Sy --noconfirm "$pkg_name" >/dev/null 2>&1 || true
        elif command -v sudo >/dev/null 2>&1; then
            sudo pacman -Sy --noconfirm "$pkg_name" >/dev/null 2>&1 || true
        fi
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache "$pkg_name" >/dev/null 2>&1 || true
    fi
}

_ensure_dependencies() {
    # Check and auto-install curl, jq (Zero Python required)
    if ! command -v curl >/dev/null 2>&1; then
        _auto_install_pkg curl
    fi
    if ! command -v jq >/dev/null 2>&1; then
        _auto_install_pkg jq
    fi
}

_install_ollama_engine() {
    if [ "$(uname -s)" = "Darwin" ]; then
        if command -v brew >/dev/null 2>&1; then
            brew install ollama >/dev/null 2>&1 || curl -fsSL https://ollama.com/install.sh | sh >/dev/null 2>&1 || true
            brew services start ollama >/dev/null 2>&1 || (ollama serve >/dev/null 2>&1 &) || true
        else
            curl -fsSL https://ollama.com/install.sh | sh >/dev/null 2>&1 || true
            (ollama serve >/dev/null 2>&1 &) || true
        fi
    else
        curl -fsSL https://ollama.com/install.sh | sh >/dev/null 2>&1 || true
        if command -v systemctl >/dev/null 2>&1; then
            systemctl start ollama >/dev/null 2>&1 || (ollama serve >/dev/null 2>&1 &) || true
        else
            (ollama serve >/dev/null 2>&1 &) || true
        fi
    fi

    # Wait up to 5s for Ollama server to become available
    for _ in {1..10}; do
        if curl -s --max-time 1 http://localhost:11434/api/tags >/dev/null 2>&1; then
            break
        fi
        sleep 0.5
    done
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
    local nav_hint="(Navegue com ↑/↓ e Enter)"
    [ "$CHOSEN_LANG" = "en-US" ] && nav_hint="(Navigate with ↑/↓ and Enter)"
    [ "$CHOSEN_LANG" = "es-ES" ] && nav_hint="(Navega con ↑/↓ y Enter)"
    printf "  \033[38;5;248m%s\033[0m \033[38;5;240m%s\033[0m\n" "$step_title" "$nav_hint"

    while true; do
        # Render options
        local idx=0
        for opt in "${options[@]}"; do
            if [ "$idx" -eq "$selected" ]; then
                printf "     \033[1;37;48;5;236m ▸ %-62s \033[0m\033[K\n" "$opt"
            else
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

            if [ "$c3" = "A" ]; then # UP
                if [ $selected -gt 0 ]; then
                    selected=$((selected - 1))
                else
                    selected=$((count - 1))
                fi
            elif [ "$c3" = "B" ]; then # DOWN
                if [ $selected -lt $((count - 1)) ]; then
                    selected=$((selected + 1))
                else
                    selected=0
                fi
            fi
        elif [ "$c1" = "k" ] || [ "$c1" = "K" ]; then
            [ $selected -gt 0 ] && selected=$((selected - 1)) || selected=$((count - 1))
        elif [ "$c1" = "j" ] || [ "$c1" = "J" ]; then
            [ $selected -lt $((count - 1)) ] && selected=$((selected + 1)) || selected=0
        elif [ "$c1" = "1" ]; then
            selected=0; break
        elif [ "$c1" = "2" ] && [ $count -gt 1 ]; then
            selected=1; break
        elif [ "$c1" = "3" ] && [ $count -gt 2 ]; then
            selected=2; break
        elif [ "$c1" = "4" ] && [ $count -gt 3 ]; then
            selected=3; break
        elif [ "$c1" = "" ] || [ "$c1" = $'\n' ] || [ "$c1" = $'\r' ]; then
            break
        elif [ "$c1" = $'\x03' ]; then # Ctrl+C
            _cleanup_menu
            echo ""
            echo "Installation canceled."
            exit 130
        fi

        # Move cursor back up to redraw menu in place
        printf "\033[%dA" "$count"
    done

    _cleanup_menu

    # Dynamic in-place collapse
    printf "\033[%dA\033[J" "$((count + 1))"
    local raw_chosen="${options[$selected]}"
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

_animate_intro() {
    clear 2>/dev/null || true
    printf "\n"
    tput civis 2>/dev/null || printf "\033[?25l"

    printf "  \033[1;37m✦  P O W E R A I\033[0m\n"
    printf "     \033[38;5;244mCamada Cognitiva & Copiloto para Terminal\033[0m\n\n"

    # Sweeping light beam
    local width=58
    for pos in $(seq 0 3 $width); do
        printf "\r  "
        for ((i=0; i<width; i++)); do
            local dist=$(( i - pos ))
            [ $dist -lt 0 ] && dist=$(( -dist ))
            if [ $dist -eq 0 ]; then
                printf "\033[1;37m━\033[0m"
            elif [ $dist -eq 1 ]; then
                printf "\033[38;5;252m─\033[0m"
            elif [ $dist -eq 2 ]; then
                printf "\033[38;5;246m─\033[0m"
            elif [ $dist -eq 3 ]; then
                printf "\033[38;5;241m─\033[0m"
            else
                printf "\033[38;5;236m─\033[0m"
            fi
        done
        sleep 0.015
    done
    
    printf "\r  \033[38;5;238m──────────────────────────────────────────────────────────\033[0m\n\n"
    tput cnorm 2>/dev/null || printf "\033[?25h"
}

_uninstall_powerai() {
    local lang="$1"
    local install_dir="$HOME/.powerai"

    _clean_rc() {
        local f="$1"
        if [ -f "$f" ] && grep -q "powerai" "$f" 2>/dev/null; then
            grep -v "powerai" "$f" > "${f}.powerai_tmp" 2>/dev/null && mv "${f}.powerai_tmp" "$f"
        fi
    }

    _spin_step "Limpando perfis de terminal (.zshrc, .bashrc)..." "_clean_rc '$HOME/.bashrc'; _clean_rc '$HOME/.zshrc'; _clean_rc '$HOME/.bash_profile'; _clean_rc '$HOME/.profile'"
    _spin_step "Removendo pasta $install_dir..." "rm -rf '$install_dir'"

    echo ""
    echo -e "  \033[38;5;238m─────────────────────────────────────────────────────────────\033[0m"
    if [ "$lang" = "en-US" ]; then
        echo -e "  \033[1;37m✦  PowerAI was successfully uninstalled!\033[0m"
        echo ""
        echo -e "    \033[38;5;244mTo refresh your terminal immediately, run:\033[0m"
        echo -e "      \033[1;37msource ~/.zshrc\033[0m \033[38;5;240m(or source ~/.bashrc)\033[0m"
    elif [ "$lang" = "es-ES" ]; then
        echo -e "  \033[1;37m✦  ¡PowerAI fue desinstalado con éxito!\033[0m"
        echo ""
        echo -e "    \033[38;5;244mPara aplicar los cambios en la terminal actual, ejecuta:\033[0m"
        echo -e "      \033[1;37msource ~/.zshrc\033[0m \033[38;5;240m(o source ~/.bashrc)\033[0m"
    else
        echo -e "  \033[1;37m✦  PowerAI foi desinstalado com sucesso!\033[0m"
        echo ""
        echo -e "    \033[38;5;244mPara aplicar as alterações no terminal atual, execute:\033[0m"
        echo -e "      \033[1;37msource ~/.zshrc\033[0m \033[38;5;240m(ou source ~/.bashrc)\033[0m"
    fi
    echo -e "  \033[38;5;238m─────────────────────────────────────────────────────────────\033[0m"
    echo ""
    exit 0
}

# --- RENDER INTRO ---
_animate_intro

# Quick mode check
QUICK_MODE=false
if [ "$1" = "--quick" ] || [ "$1" = "-y" ] || [ "$1" = "--yes" ]; then
    QUICK_MODE=true
fi

# Step 1: Automatic System Language Detection
CHOSEN_LANG=$(_detect_os_language)

# CLI flags override if provided (e.g. --lang=en or --lang=es)
for arg in "$@"; do
    case "$arg" in
        --lang=en|--lang=en-US|--en) CHOSEN_LANG="en-US" ;;
        --lang=es|--lang=es-ES|--es) CHOSEN_LANG="es-ES" ;;
        --lang=pt|--lang=pt-BR|--pt) CHOSEN_LANG="pt-BR" ;;
    esac
done

INSTALL_DIR="$HOME/.powerai"
ALREADY_INSTALLED=false
if [ -f "$INSTALL_DIR/powerai.sh" ] || [ -f "$INSTALL_DIR/config.json" ]; then
    ALREADY_INSTALLED=true
fi

# Direct CLI action flags
for arg in "$@"; do
    case "$arg" in
        --uninstall|--remove)
            _uninstall_powerai "$CHOSEN_LANG"
            ;;
        --fresh|--force)
            ALREADY_INSTALLED=false
            ;;
    esac
done

RECONFIGURE_ONLY=false

# Existing Installation Detection & Interactive Management
if [ "$ALREADY_INSTALLED" = true ] && [ "$QUICK_MODE" = false ]; then
    CURRENT_VERSION="v1.2.0"
    CURRENT_MODE="Auto"
    CURRENT_MODEL="qwen2.5-coder:1.5b"
    if [ -f "$INSTALL_DIR/config.json" ]; then
        CURRENT_MODE=$(grep -o '"Mode": *"[^"]*"' "$INSTALL_DIR/config.json" 2>/dev/null | cut -d'"' -f4 || echo "Auto")
        CURRENT_MODEL=$(grep -o '"LocalModel": *"[^"]*"' "$INSTALL_DIR/config.json" 2>/dev/null | cut -d'"' -f4 || echo "qwen2.5-coder:1.5b")
    fi

    if [ "$CHOSEN_LANG" = "en-US" ]; then
        echo -e "  \033[1;32m●\033[0m  \033[1;37mPowerAI is already installed on your system.\033[0m"
        echo -e "     \033[38;5;244mVersion:\033[0m       \033[38;5;252m$CURRENT_VERSION\033[0m"
        echo -e "     \033[38;5;244mPath:\033[0m          \033[38;5;252m$INSTALL_DIR\033[0m"
        echo -e "     \033[38;5;244mProvider:\033[0m      \033[38;5;252m$CURRENT_MODE ($CURRENT_MODEL)\033[0m"
        echo ""
        title_action="What would you like to do?"
        action_options=(
            "1) Update / Reinstall   · Pull latest version and refresh dependencies"
            "2) Reconfigure Provider · Change AI model, provider, or API keys"
            "3) Uninstall            · Remove PowerAI and clean terminal profiles"
            "4) Cancel / Exit        · Keep current version without changes"
        )
    elif [ "$CHOSEN_LANG" = "es-ES" ]; then
        echo -e "  \033[1;32m●\033[0m  \033[1;37mPowerAI ya está instalado en tu sistema.\033[0m"
        echo -e "     \033[38;5;244mVersión:\033[0m       \033[38;5;252m$CURRENT_VERSION\033[0m"
        echo -e "     \033[38;5;244mUbicación:\033[0m     \033[38;5;252m$INSTALL_DIR\033[0m"
        echo -e "     \033[38;5;244mProveedor:\033[0m     \033[38;5;252m$CURRENT_MODE ($CURRENT_MODEL)\033[0m"
        echo ""
        title_action="¿Qué deseas hacer?"
        action_options=(
            "1) Actualizar / Reinstalar · Descarga la última versión y actualiza dependencias"
            "2) Reconfigurar Proveedor · Cambia modelo o claves de IA"
            "3) Desinstalar            · Elimina PowerAI y limpia perfiles de shell"
            "4) Cancelar / Salir       · Mantener versión actual sin cambios"
        )
    else
        echo -e "  \033[1;32m●\033[0m  \033[1;37mPowerAI já está instalado no seu sistema.\033[0m"
        echo -e "     \033[38;5;244mVersão:\033[0m        \033[38;5;252m$CURRENT_VERSION\033[0m"
        echo -e "     \033[38;5;244mLocalização:\033[0m   \033[38;5;252m$INSTALL_DIR\033[0m"
        echo -e "     \033[38;5;244mProvedor:\033[0m      \033[38;5;252m$CURRENT_MODE ($CURRENT_MODEL)\033[0m"
        echo ""
        title_action="O que deseja fazer?"
        action_options=(
            "1) Atualizar / Reinstalar   · Baixa a versão mais recente e atualiza dependências"
            "2) Reconfigurar Provedor    · Alterar modelo/chave de IA (Ollama, OpenAI, Groq)"
            "3) Desinstalar              · Remove o PowerAI e limpa os hooks do shell"
            "4) Cancelar / Sair          · Manter a versão atual sem alterações"
        )
    fi

    CHOSEN_ACTION_IDX=0
    _select_menu CHOSEN_ACTION_IDX "$title_action" "${action_options[@]}"

    case "$CHOSEN_ACTION_IDX" in
        0) # Reinstall / Update
            ;;
        1) # Reconfigure Provider
            RECONFIGURE_ONLY=true
            ;;
        2) # Uninstall
            _uninstall_powerai "$CHOSEN_LANG"
            ;;
        3|*) # Cancel
            echo ""
            if [ "$CHOSEN_LANG" = "en-US" ]; then
                echo -e "  \033[38;5;244mOperation canceled. PowerAI was not modified.\033[0m\n"
            elif [ "$CHOSEN_LANG" = "es-ES" ]; then
                echo -e "  \033[38;5;244mOperación cancelada. PowerAI no fue modificado.\033[0m\n"
            else
                echo -e "  \033[38;5;244mOperação cancelada. O PowerAI foi mantido sem alterações.\033[0m\n"
            fi
            exit 0
            ;;
    esac
fi

if [ "$RECONFIGURE_ONLY" = false ]; then
    lang_label="Português (Brasil)"
    [ "$CHOSEN_LANG" = "en-US" ] && lang_label="English (US)"
    [ "$CHOSEN_LANG" = "es-ES" ] && lang_label="Español"

    step1_text="1. Idioma do Sistema:       $lang_label (Auto-detectado)"
    [ "$CHOSEN_LANG" = "en-US" ] && step1_text="1. System Language:         $lang_label (Auto-detected)"
    [ "$CHOSEN_LANG" = "es-ES" ] && step1_text="1. Idioma del Sistema:      $lang_label (Auto-detectado)"

    _spin_step "$step1_text" "sleep 0.2"

    # Step 2: Detect and auto-resolve dependencies
    msg_dep="2. Ambiente & Dependências:  curl, jq prontos (Zero Python)"
    [ "$CHOSEN_LANG" = "en-US" ] && msg_dep="2. Environment & Tools:      curl, jq ready (Zero Python)"
    [ "$CHOSEN_LANG" = "es-ES" ] && msg_dep="2. Entorno y Herramientas:   curl, jq listos (Zero Python)"
    _spin_step "$msg_dep" "_ensure_dependencies"
fi

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
    # Step 3: Provider Selection
    title_prov="3. Provedor de IA:"
    [ "$CHOSEN_LANG" = "en-US" ] && title_prov="3. AI Provider:"
    [ "$CHOSEN_LANG" = "es-ES" ] && title_prov="3. Proveedor de IA:"

    if [ "$CHOSEN_LANG" = "en-US" ]; then
        menu_providers=(
            "1) Local Ollama     · Recommended: ultra-fast, offline, <1s"
            "2) Local API        · OMLX, LM Studio, vLLM on :5151 / :8000"
            "3) Cloud            · OpenAI gpt-4o-mini / Groq / OpenRouter"
            "4) Automatic        · Detects locally with cloud fallback"
        )
    elif [ "$CHOSEN_LANG" = "es-ES" ]; then
        menu_providers=(
            "1) Ollama Local     · Recomendado: ultrarrápido, offline, <1s"
            "2) API Local        · OMLX, LM Studio, vLLM en :5151 / :8000"
            "3) Nube             · OpenAI gpt-4o-mini / Groq / OpenRouter"
            "4) Automático       · Detecta localmente con fallback a nube"
        )
    else
        menu_providers=(
            "1) Ollama Local     · Recomendado: ultrarrápido, offline, <1s"
            "2) API Local        · OMLX, LM Studio, vLLM em :5151 / :8000"
            "3) Nuvem            · OpenAI gpt-4o-mini / Groq / OpenRouter"
            "4) Automático       · Detecta localmente e faz fallback nuvem"
        )
    fi

    CHOSEN_PROV_IDX=0
    _select_menu CHOSEN_PROV_IDX "$title_prov" "${menu_providers[@]}"

    case "$CHOSEN_PROV_IDX" in
        1)
            CHOSEN_MODE="Local"
            CHOSEN_LOCAL_TYPE="OpenAICompatible"
            title_lm="4. Modelo da API Local:"
            [ "$CHOSEN_LANG" = "en-US" ] && title_lm="4. Local API Model:"
            [ "$CHOSEN_LANG" = "es-ES" ] && title_lm="4. Modelo de API Local:"
            menu_local_models=(
                "1) qwen2.5-coder:1.5b                       · Mais leve (<1s)"
                "2) mlx-community--Qwen2.5-7B-Instruct-4bit  · Alta capacidade"
                "3) Personalizado                            · Digitar manualmente"
            )
            CHOSEN_LM_IDX=0
            _select_menu CHOSEN_LM_IDX "$title_lm" "${menu_local_models[@]}"
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
            title_cm="4. Modelo de Nuvem:"
            [ "$CHOSEN_LANG" = "en-US" ] && title_cm="4. Cloud Model:"
            [ "$CHOSEN_LANG" = "es-ES" ] && title_cm="4. Modelo de Nube:"
            menu_cloud_models=(
                "1) gpt-4o-mini               · Recomendado (Rápido e econômico)"
                "2) gpt-4o                    · Modelo completo de alta inteligência"
                "3) llama-3.3-70b-versatile   · Groq Cloud ultrarrápido"
                "4) Personalizado             · Digitar outro nome de modelo"
            )
            CHOSEN_CM_IDX=0
            _select_menu CHOSEN_CM_IDX "$title_cm" "${menu_cloud_models[@]}"
            case "$CHOSEN_CM_IDX" in
                0) CHOSEN_CLOUD_MODEL="gpt-4o-mini" ;;
                1) CHOSEN_CLOUD_MODEL="gpt-4o" ;;
                2) CHOSEN_CLOUD_MODEL="llama-3.3-70b-versatile" ;;
                *) CHOSEN_CLOUD_MODEL=$(_read_line "     Model name: " "gpt-4o-mini") ;;
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

            # Auto-install Ollama engine if not present
            if [ "$OLLAMA_INSTALLED" = false ]; then
                title_inst_ollama="Instalar Ollama no sistema?"
                [ "$CHOSEN_LANG" = "en-US" ] && title_inst_ollama="Install Ollama on your system?"
                [ "$CHOSEN_LANG" = "es-ES" ] && title_inst_ollama="¿Instalar Ollama en el sistema?"
                menu_inst_ollama=(
                    "1) Sim, instalar Ollama automaticamente (Recomendado)"
                    "2) Não, vou configurar manualmente"
                )
                [ "$CHOSEN_LANG" = "en-US" ] && menu_inst_ollama=(
                    "1) Yes, install Ollama automatically (Recommended)"
                    "2) No, I will setup manually"
                )
                [ "$CHOSEN_LANG" = "es-ES" ] && menu_inst_ollama=(
                    "1) Sí, instalar Ollama automáticamente (Recomendado)"
                    "2) No, configuraré manualmente"
                )

                CHOSEN_INST_OLLAMA_IDX=0
                _select_menu CHOSEN_INST_OLLAMA_IDX "$title_inst_ollama" "${menu_inst_ollama[@]}"
                if [ "$CHOSEN_INST_OLLAMA_IDX" -eq 0 ]; then
                    _spin_step "Instalando e iniciando Ollama..." "_install_ollama_engine"
                    OLLAMA_INSTALLED=true
                fi
            fi

            title_om="4. Modelo Ollama:"
            [ "$CHOSEN_LANG" = "en-US" ] && title_om="4. Ollama Model:"
            [ "$CHOSEN_LANG" = "es-ES" ] && title_om="4. Modelo Ollama:"
            menu_ollama_models=(
                "1) qwen2.5-coder:1.5b  · Recomendado (Ultraleve, <1s, Apple Metal GPU)"
                "2) qwen2.5-coder:7b    · Mais inteligente (Requer ~5GB de RAM)"
                "3) deepseek-coder:1.3b · Alternativa compacta e rápida"
                "4) Personalizado       · Digitar outro nome de modelo"
            )
            CHOSEN_OM_IDX=0
            _select_menu CHOSEN_OM_IDX "$title_om" "${menu_ollama_models[@]}"
            case "$CHOSEN_OM_IDX" in
                0) CHOSEN_LOCAL_MODEL="qwen2.5-coder:1.5b" ;;
                1) CHOSEN_LOCAL_MODEL="qwen2.5-coder:7b" ;;
                2) CHOSEN_LOCAL_MODEL="deepseek-coder:1.3b" ;;
                *) CHOSEN_LOCAL_MODEL=$(_read_line "     Nome do modelo Ollama: " "qwen2.5-coder:1.5b") ;;
            esac

            # Offer model download if Ollama is available
            if [ "$OLLAMA_INSTALLED" = true ]; then
                if ! ollama list 2>/dev/null | grep -q "$CHOSEN_LOCAL_MODEL"; then
                    title_dl="Baixar modelo agora?"
                    [ "$CHOSEN_LANG" = "en-US" ] && title_dl="Download model now?"
                    [ "$CHOSEN_LANG" = "es-ES" ] && title_dl="¿Descargar modelo ahora?"
                    menu_dl=(
                        "1) Sim, baixar agora via ollama pull"
                        "2) Não, vou baixar manualmente mais tarde"
                    )
                    [ "$CHOSEN_LANG" = "en-US" ] && menu_dl=(
                        "1) Yes, download now via ollama pull"
                        "2) Skip, I will download later manually"
                    )
                    [ "$CHOSEN_LANG" = "es-ES" ] && menu_dl=(
                        "1) Sí, descargar ahora vía ollama pull"
                        "2) Omitir, descargaré manualmente más tarde"
                    )

                    CHOSEN_DL_IDX=0
                    _select_menu CHOSEN_DL_IDX "$title_dl" "${menu_dl[@]}"
                    if [ "$CHOSEN_DL_IDX" -eq 0 ]; then
                        echo ""
                        echo -e "     \033[38;5;244mBaixando modelo no Ollama (aguarde alguns instantes)...\033[0m"
                        ollama pull "$CHOSEN_LOCAL_MODEL" || true
                    fi
                fi
            fi
            ;;
    esac

    # Step 5: Terminal Features
    title_ft="5. Recursos de Terminal:"
    [ "$CHOSEN_LANG" = "en-US" ] && title_ft="5. Terminal Features:"
    [ "$CHOSEN_LANG" = "es-ES" ] && title_ft="5. Funciones de Terminal:"

    if [ "$CHOSEN_LANG" = "en-US" ]; then
        menu_features=(
            "1) Enable automatic error fixes & suggestions (Default)"
            "2) Manual queries only (Explicit 'ai' or '?' commands)"
        )
    elif [ "$CHOSEN_LANG" = "es-ES" ]; then
        menu_features=(
            "1) Activar corrección y sugerencia automática de errores (Predeterminado)"
            "2) Solo responder a consultas manuales ('ai' o '?')"
        )
    else
        menu_features=(
            "1) Sugestões e correções automáticas em erros ativadas (Padrão)"
            "2) Apenas responder a consultas manuais ('ai' ou '?')"
        )
    fi
    CHOSEN_FT_IDX=0
    _select_menu CHOSEN_FT_IDX "$title_ft" "${menu_features[@]}"
    if [ "$CHOSEN_FT_IDX" -eq 1 ]; then
        CHOSEN_AUTO_SUGGEST=false
    fi
fi

# Step 6: Installation Execution
title_inst="6. Instalando arquivos e configurando:"
[ "$CHOSEN_LANG" = "en-US" ] && title_inst="6. Installing and configuring files:"
[ "$CHOSEN_LANG" = "es-ES" ] && title_inst="6. Instalando y configurando archivos:"
echo ""
echo -e "  \033[38;5;248m$title_inst\033[0m"

INSTALL_DIR="$HOME/.powerai"
_spin_step "Criando diretório $INSTALL_DIR..." "mkdir -p '$INSTALL_DIR'"

# Copy or download files
if [ -f "$(dirname "$0")/powerai.sh" ]; then
    _spin_step "Instalando script principal (powerai.sh)..." "cp '$(dirname "$0")/powerai.sh' '$INSTALL_DIR/powerai.sh'"
else
    _spin_step "Baixando script principal (powerai.sh)..." "curl -fsSL 'https://raw.githubusercontent.com/Luizhcrs/powerai/main/powerai.sh' -o '$INSTALL_DIR/powerai.sh'"
fi

if [ -f "$(dirname "$0")/uninstall.sh" ]; then
    _spin_step "Instalando desinstalador (uninstall.sh)..." "cp '$(dirname "$0")/uninstall.sh' '$INSTALL_DIR/uninstall.sh'"
else
    _spin_step "Baixando desinstalador (uninstall.sh)..." "curl -fsSL 'https://raw.githubusercontent.com/Luizhcrs/powerai/main/uninstall.sh' -o '$INSTALL_DIR/uninstall.sh'"
fi

chmod +x "$INSTALL_DIR/powerai.sh" "$INSTALL_DIR/uninstall.sh" 2>/dev/null || true

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
  "Language": "$CHOSEN_LANG",
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
if [ "$CHOSEN_LANG" = "en-US" ]; then
    if [ "$RECONFIGURE_ONLY" = true ]; then
        echo -e "  \033[1;37m✦  PowerAI configuration updated successfully!\033[0m"
    else
        echo -e "  \033[1;37m✦  PowerAI successfully installed!\033[0m"
    fi
    echo ""
    echo -e "    \033[38;5;244m• Provider:\033[0m  \033[1;37m$CHOSEN_MODE ($CHOSEN_LOCAL_MODEL)\033[0m"
    echo -e "    \033[38;5;244m• Language:\033[0m  \033[1;37m$CHOSEN_LANG\033[0m"
    echo -e "    \033[38;5;244m• Path:\033[0m      \033[38;5;250m$INSTALL_DIR\033[0m"
    echo -e "    \033[38;5;244m• Config:\033[0m    \033[38;5;250m$CONFIG_FILE\033[0m"
    echo ""
    echo -e "    \033[38;5;245mTo activate in current terminal, run:\033[0m"
    echo -e "      \033[1;37msource ~/.zshrc\033[0m \033[38;5;240m(or source ~/.bashrc)\033[0m"
    echo ""
    echo -e "    \033[38;5;245mAvailable commands:\033[0m"
    echo -e "      \033[38;5;250mai <query>\033[0m         · Natural language terminal query"
    echo -e "      \033[38;5;250m? <query>\033[0m          · Fast shorthand alias"
    echo -e "      \033[38;5;250mai language <lang>\033[0m· Change language (pt | en | es)"
    echo -e "      \033[38;5;250mai config\033[0m          · View active configuration"
    echo -e "      \033[38;5;250mai uninstall\033[0m       · Complete uninstallation"
elif [ "$CHOSEN_LANG" = "es-ES" ]; then
    if [ "$RECONFIGURE_ONLY" = true ]; then
        echo -e "  \033[1;37m✦  ¡Configuración de PowerAI actualizada con éxito!\033[0m"
    else
        echo -e "  \033[1;37m✦  ¡PowerAI instalado con éxito!\033[0m"
    fi
    echo ""
    echo -e "    \033[38;5;244m• Proveedor:\033[0m \033[1;37m$CHOSEN_MODE ($CHOSEN_LOCAL_MODEL)\033[0m"
    echo -e "    \033[38;5;244m• Idioma:\033[0m    \033[1;37m$CHOSEN_LANG\033[0m"
    echo -e "    \033[38;5;244m• Destino:\033[0m   \033[38;5;250m$INSTALL_DIR\033[0m"
    echo -e "    \033[38;5;244m• Config:\033[0m    \033[38;5;250m$CONFIG_FILE\033[0m"
    echo ""
    echo -e "    \033[38;5;245mPara activar en la terminal actual, ejecuta:\033[0m"
    echo -e "      \033[1;37msource ~/.zshrc\033[0m \033[38;5;240m(o source ~/.bashrc)\033[0m"
    echo ""
    echo -e "    \033[38;5;245mComandos disponibles:\033[0m"
    echo -e "      \033[38;5;250mai <consulta>\033[0m      · Consulta en lenguaje natural"
    echo -e "      \033[38;5;250m? <consulta>\033[0m       · Atajo rápido"
    echo -e "      \033[38;5;250mai language <lang>\033[0m· Cambiar idioma (pt | en | es)"
    echo -e "      \033[38;5;250mai config\033[0m          · Ver configuración activa"
    echo -e "      \033[38;5;250mai uninstall\033[0m       · Desinstalación completa"
else
    if [ "$RECONFIGURE_ONLY" = true ]; then
        echo -e "  \033[1;37m✦  Configurações do PowerAI atualizadas com sucesso!\033[0m"
    else
        echo -e "  \033[1;37m✦  PowerAI instalado com sucesso!\033[0m"
    fi
    echo ""
    echo -e "    \033[38;5;244m• Provedor:\033[0m  \033[1;37m$CHOSEN_MODE ($CHOSEN_LOCAL_MODEL)\033[0m"
    echo -e "    \033[38;5;244m• Idioma:\033[0m    \033[1;37m$CHOSEN_LANG\033[0m"
    echo -e "    \033[38;5;244m• Destino:\033[0m   \033[38;5;250m$INSTALL_DIR\033[0m"
    echo -e "    \033[38;5;244m• Config:\033[0m    \033[38;5;250m$CONFIG_FILE\033[0m"
    echo ""
    echo -e "    \033[38;5;245mPara ativar no terminal atual, execute:\033[0m"
    echo -e "      \033[1;37msource ~/.zshrc\033[0m \033[38;5;240m(ou source ~/.bashrc)\033[0m"
    echo ""
    echo -e "    \033[38;5;245mComandos disponíveis:\033[0m"
    echo -e "      \033[38;5;250mai <pergunta>\033[0m      · Consulta em linguagem natural"
    echo -e "      \033[38;5;250m? <pergunta>\033[0m       · Atalho rápido"
    echo -e "      \033[38;5;250mai language <lang>\033[0m· Trocar idioma (pt | en | es)"
    echo -e "      \033[38;5;250mai config\033[0m          · Ver configurações ativas"
    echo -e "      \033[38;5;250mai uninstall\033[0m       · Desinstalação completa"
fi
echo -e "  \033[38;5;238m─────────────────────────────────────────────────────────────\033[0m"
echo ""
