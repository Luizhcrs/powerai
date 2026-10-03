#!/usr/bin/env bash
# test_harness.sh - Automated Unit & Regression Test Suite for PowerAI
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

PASSED=0
FAILED=0

assert_equal() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [ "$expected" = "$actual" ]; then
        echo "  [PASS] $test_name"
        PASSED=$((PASSED + 1))
    else
        echo "  [FAIL] $test_name"
        echo "         Esperado: '$expected'"
        echo "         Obtido:   '$actual'"
        FAILED=$((FAILED + 1))
    fi
}

echo "=========================================================="
echo " [PowerAI] Executando Bateria de Testes Automatizados"
echo "=========================================================="
echo ""

# 1. Testes de Extração Multi-Formato do Parser Nativo (Zero Python)
echo "1. Testando _powerai_parse_response (Parser Nativo JQ/Shell):"

source ./powerai.sh

# Caso 1: JSON Puro
raw1='{"choices":[{"message":{"content":"{\"suggested_command\": \"ls -la\", \"explanation\": \"Lista detalhada\"}"}}]}'
res1=$(_powerai_parse_response "$raw1")
cmd1=$(echo "$res1" | cut -f1)
exp1=$(echo "$res1" | cut -f2)
assert_equal "JSON Puro - Comando" "ls -la" "$cmd1"
assert_equal "JSON Puro - Explicacao" "Lista detalhada" "$exp1"

# Caso 2: Markdown com bloco JSON embutido
raw2='{"choices":[{"message":{"content":"```json\n{\n  \"suggested_command\": \"df -h\",\n  \"explanation\": \"Espaco livre em disco\"\n}\n```"}}]}'
res2=$(_powerai_parse_response "$raw2")
cmd2=$(echo "$res2" | cut -f1)
exp2=$(echo "$res2" | cut -f2)
assert_equal "Markdown JSON - Comando" "df -h" "$cmd2"
assert_equal "Markdown JSON - Explicacao" "Espaco livre em disco" "$exp2"

# Caso 3: Bloco de código Bash simples
raw3='{"choices":[{"message":{"content":"```bash\nifconfig en0\n```"}}]}'
res3=$(_powerai_parse_response "$raw3")
cmd3=$(echo "$res3" | cut -f1)
assert_equal "Markdown Bash Puro - Comando" "ifconfig en0" "$cmd3"

# Caso 4: Resposta Puramente Informativa (Sem comando a executar)
raw4='{"message":{"content":"{\"suggested_command\": \"\", \"explanation\": \"Seu IP local DHCP é 192.168.0.102.\"}"}}'
res4=$(_powerai_parse_response "$raw4")
cmd4=$(echo "$res4" | cut -f1)
exp4=$(echo "$res4" | cut -f2)
assert_equal "Resposta Informativa - Comando Vazio" "" "$cmd4"
assert_equal "Resposta Informativa - Dado Extraido" "Seu IP local DHCP é 192.168.0.102." "$exp4"

# 2. Testes de Carregamento e Memória do powerai.sh
echo ""
echo "2. Testando powerai.sh (Carregamento de Contexto & Memória):"

source ./powerai.sh

_powerai_load_config
assert_equal "Configuracao - LocalModel default" "qwen2.5-coder:1.5b" "$POWERAI_LOCAL_MODEL"
assert_equal "Configuracao - Timeout default" "25" "$POWERAI_TIMEOUT"

# Teste de Memória da Sessão
POWERAI_SESSION_MEMORY=()
_powerai_add_session "como ver ip" "ifconfig" "lo0: 127.0.0.1\nen0: 192.168.0.102"

ctx=$(_powerai_get_context)
if [[ "$ctx" == *"192.168.0.102"* ]]; then
    echo "  [PASS] Memória de Sessão - Saída do terminal gravada no contexto"
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Memória de Sessão - Falha ao gravar saída no contexto"
    FAILED=$((FAILED + 1))
fi

if [[ "$ctx" == *"(CWD):"* ]]; then
    echo "  [PASS] Context Collector - Diretório atual detectado"
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Context Collector - CWD não detectado"
    FAILED=$((FAILED + 1))
fi

# 3. Testes de Funções Git e Explain (v1.1.0)
echo ""
echo "3. Testando Módulos Especializados (ai commit, ai explain, Fish):"
if type _powerai_git_commit >/dev/null 2>&1; then
    echo "  [PASS] Módulo Git Commit carregado"
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Módulo Git Commit ausente"
    FAILED=$((FAILED + 1))
fi

if type _powerai_explain_command >/dev/null 2>&1; then
    echo "  [PASS] Módulo Explain Command carregado"
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Módulo Explain Command ausente"
    FAILED=$((FAILED + 1))
fi

if [ -f "./powerai.fish" ]; then
    echo "  [PASS] Módulo Fish Shell presente"
    PASSED=$((PASSED + 1))
else
    echo "  [FAIL] Módulo Fish Shell ausente"
    FAILED=$((FAILED + 1))
fi

# 4. Testes do Módulo Apple Intelligence (macOS FoundationModels)
echo ""
echo "4. Testando Módulo Apple Intelligence (macOS FoundationModels):"
if [ "$(uname -s)" = "Darwin" ]; then
    _powerai_load_config
    if [ -x "$POWERAI_APPLE_BIN" ]; then
        echo "  [PASS] Binário powerai-apple localizado e executável"
        PASSED=$((PASSED + 1))

        check_out=$("$POWERAI_APPLE_BIN" check 2>/dev/null || true)
        is_avail=$(echo "$check_out" | jq -r '.available // false' 2>/dev/null)
        if [ "$is_avail" = "true" ]; then
            echo "  [PASS] Apple Intelligence - SystemLanguageModel disponível"
            PASSED=$((PASSED + 1))
        else
            echo "  [WARN] Apple Intelligence - SystemLanguageModel indisponível neste hardware"
        fi

        # Teste de query com o binário
        query_out=$("$POWERAI_APPLE_BIN" query --prompt "como listar arquivos" --lang "pt-BR" 2>/dev/null || true)
        parsed_apple=$(_powerai_parse_response "$query_out")
        apple_cmd=$(echo "$parsed_apple" | cut -f1)
        if [ -n "$apple_cmd" ]; then
            echo "  [PASS] Apple Intelligence Query - Comando sugerido: '$apple_cmd'"
            PASSED=$((PASSED + 1))
        else
            echo "  [FAIL] Apple Intelligence Query - Falha na extração de comando"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "  [WARN] Binário powerai-apple não compilado (execute src/PowerAI.Apple/build.sh)"
    fi
else
    echo "  [SKIP] Sistema não é macOS; testes de Apple Intelligence ignorados."
fi

echo ""
echo "=========================================================="
echo " Resumo dos Testes:"
echo "   Passaram: $PASSED"
echo "   Falharam: $FAILED"
echo "=========================================================="

if [ $FAILED -eq 0 ]; then
    echo " [SUCESSO] Todos os testes passaram com êxito!"
    exit 0
else
    echo " [ERRO] Alguns testes falharam."
    exit 1
fi
