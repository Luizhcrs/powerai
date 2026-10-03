#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "=========================================================="
echo " [PowerAI.Apple] Compilando módulo nativo Apple Intelligence"
echo "=========================================================="

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Erro: O módulo Apple Intelligence só pode ser compilado no macOS." >&2
    exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "Erro: Ferramenta 'swift' não encontrada. Instale o Xcode ou Command Line Tools." >&2
    exit 1
fi

echo -n "  Compilando binário nativo (Release arm64)... "
swift build -c release >/dev/null

mkdir -p bin
cp .build/release/powerai-apple bin/powerai-apple
chmod +x bin/powerai-apple

echo -e "\033[1;32m[OK]\033[0m"
echo "  ✓ Binário compilado com sucesso em: $DIR/bin/powerai-apple"
echo ""
echo "  Testando disponibilidade de Apple Intelligence no sistema:"
"$DIR/bin/powerai-apple" check || true
echo ""
