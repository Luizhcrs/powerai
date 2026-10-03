#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

VERSION="v1.3.0"
DMG_NAME="PowerAI-${VERSION}-macOS-arm64.dmg"
STAGING_DIR="/tmp/powerai_dmg_staging_$$"

echo "=========================================================="
echo " [PowerAI] Gerando imagem de disco DMG: $DMG_NAME"
echo "=========================================================="

# 1. Garantir que o binário Apple Intelligence está compilado
if [ ! -f "src/PowerAI.Apple/bin/powerai-apple" ]; then
    echo "  Compilando binário nativo powerai-apple..."
    ./src/PowerAI.Apple/build.sh
fi

# 2. Criar área de montagem
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
mkdir -p "$STAGING_DIR/bin"

# 3. Copiar arquivos necessários
cp powerai.sh "$STAGING_DIR/"
cp powerai.fish "$STAGING_DIR/"
cp install.sh "$STAGING_DIR/"
cp uninstall.sh "$STAGING_DIR/"
cp README.md "$STAGING_DIR/"
cp LICENSE "$STAGING_DIR/"
cp src/PowerAI.Apple/bin/powerai-apple "$STAGING_DIR/bin/"

# 4. Criar executável amigável .command para instalação via duplo-clique
cat << 'CMD' > "$STAGING_DIR/Install PowerAI.command"
#!/usr/bin/env bash
cd "$(dirname "$0")"
clear
echo "Iniciando instalador do PowerAI..."
bash install.sh
echo ""
echo "Instalação concluída! Pressione qualquer tecla para fechar."
read -n 1 -s
CMD
chmod +x "$STAGING_DIR/Install PowerAI.command"
chmod +x "$STAGING_DIR/install.sh" "$STAGING_DIR/uninstall.sh" "$STAGING_DIR/powerai.sh" "$STAGING_DIR/powerai.fish" "$STAGING_DIR/bin/powerai-apple"

# 5. Criar DMG com hdiutil
rm -f "$DMG_NAME"
echo -n "  Criando arquivo DMG comprimido (UDZO)... "
hdiutil create -volname "PowerAI ${VERSION}" \
               -srcfolder "$STAGING_DIR" \
               -ov \
               -format UDZO \
               "$DMG_NAME" >/dev/null

rm -rf "$STAGING_DIR"

echo -e "\033[1;32m[OK]\033[0m"
echo "  ✓ DMG gerado com sucesso: $DIR/$DMG_NAME"
ls -lh "$DMG_NAME"
echo ""
