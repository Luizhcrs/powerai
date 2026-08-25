#!/usr/bin/env bash
# uninstall.sh - Desinstalador do PowerAI para Linux e macOS (Bash & Zsh)
# Uso: curl -fsSL https://raw.githubusercontent.com/Luizhcrs/nuno/main/uninstall.sh | bash

set -e

echo "=========================================================="
echo " [PowerAI] Desinstalador para Linux e macOS (Bash & Zsh)"
echo "=========================================================="
echo ""

INSTALL_DIR="$HOME/.powerai"

# 1. Remover hooks dos arquivos de inicializacao do shell
clean_shell_rc() {
    local rc_file="$1"
    if [ -f "$rc_file" ]; then
        if grep -q "powerai" "$rc_file"; then
            grep -v "powerai" "$rc_file" > "${rc_file}.powerai_tmp" && mv "${rc_file}.powerai_tmp" "$rc_file"
            echo "[OK] Hooks do PowerAI removidos de $rc_file"
        fi
    fi
}

echo "[1/2] Limpando arquivos de perfil do terminal..."
clean_shell_rc "$HOME/.bashrc"
clean_shell_rc "$HOME/.zshrc"
clean_shell_rc "$HOME/.bash_profile"
clean_shell_rc "$HOME/.profile"

# 2. Remover diretorio ~/.powerai
echo "[2/2] Removendo diretorio de instalacao..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "[OK] Pasta $INSTALL_DIR removida com sucesso."
else
    echo "[INFO] Pasta $INSTALL_DIR nao encontrada."
fi

echo ""
echo "=========================================================="
echo " [SUCESSO] PowerAI foi completamente desinstalado!"
echo " Para aplicar as alteracoes imediatamente, abra um novo"
echo " terminal ou execute: source ~/.zshrc (ou ~/.bashrc)"
echo "=========================================================="
