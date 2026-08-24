#!/usr/bin/env bash
# install.sh - Universal Linux & macOS Installer for PowerAI
# Usage: curl -fsSL https://raw.githubusercontent.com/SEU-USUARIO/power/main/install.sh | bash

set -e

echo "=========================================================="
echo " [PowerAI] Instalador para Linux e macOS (Bash & Zsh)"
echo "=========================================================="
echo ""

INSTALL_DIR="$HOME/.powerai"
mkdir -p "$INSTALL_DIR"

# 1. Copiar ou baixar powerai.sh
if [ -f "$(dirname "$0")/powerai.sh" ]; then
    cp "$(dirname "$0")/powerai.sh" "$INSTALL_DIR/powerai.sh"
else
    curl -fsSL "https://raw.githubusercontent.com/Luizhcrs/nuno/main/powerai.sh" -o "$INSTALL_DIR/powerai.sh"
fi

chmod +x "$INSTALL_DIR/powerai.sh"

# 2. Configurar auto-carregamento no ~/.bashrc e ~/.zshrc
SOURCE_LINE="[ -f \"$INSTALL_DIR/powerai.sh\" ] && source \"$INSTALL_DIR/powerai.sh\""

if [ -f "$HOME/.bashrc" ] && ! grep -q "powerai.sh" "$HOME/.bashrc"; then
    echo "$SOURCE_LINE" >> "$HOME/.bashrc"
    echo "[OK] Configurado no ~/.bashrc"
fi

if [ -f "$HOME/.zshrc" ] && ! grep -q "powerai.sh" "$HOME/.zshrc"; then
    echo "$SOURCE_LINE" >> "$HOME/.zshrc"
    echo "[OK] Configurado no ~/.zshrc"
fi

echo ""
echo "=========================================================="
echo " [SUCESSO] PowerAI instalado no Linux/macOS!"
echo " Abra um novo terminal e use:"
echo "   ai <pergunta>"
echo "   ? <pergunta>"
echo "   Ou digite texto livre / comandos com erro"
echo "=========================================================="
