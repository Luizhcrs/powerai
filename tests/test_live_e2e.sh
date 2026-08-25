#!/usr/bin/env bash
# test_live_e2e.sh - Live End-to-End AI Autonomy & Response Verification
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

source ./powerai.sh
_powerai_load_config

echo "=========================================================="
echo " [PowerAI] Bateria de Testes de Autonomia em Tempo Real"
echo "=========================================================="
echo " Provedor: $POWERAI_LOCAL_TYPE ($POWERAI_OLLAMA_ENDPOINT)"
echo " Modelo:   $POWERAI_LOCAL_MODEL"
echo " Idioma:   $POWERAI_LANGUAGE"
echo ""

PASSED=0
FAILED=0

run_ai_test() {
    local test_name="$1"
    local query="$2"
    local is_error="$3"
    local expected_pattern="$4"

    echo -n "  Testing: $test_name... "

    local harness_ctx="$(_powerai_get_context)"
    local sys_prompt=""

    if [[ "$POWERAI_LANGUAGE" =~ ^en ]]; then
        sys_prompt="You are PowerAI, an expert terminal assistant for macOS (zsh).
$harness_ctx

RULES:
1. Typos -> return corrected command in suggested_command.
2. Natural queries -> return exact macOS command in suggested_command.
3. Output memory -> return answer in explanation, suggested_command empty.

Respond ONLY with JSON: {\"suggested_command\": \"...\", \"explanation\": \"...\"}"
    else
        sys_prompt="Você é o PowerAI, um copiloto de terminal para macOS (zsh).
$harness_ctx

REGRAS:
1. Typos -> coloque o comando corrigido em suggested_command.
2. Perguntas -> coloque o comando macOS exato em suggested_command.
3. Memória de saída -> responda em explanation e deixe suggested_command vazio.

Responda APENAS com JSON: {\"suggested_command\": \"...\", \"explanation\": \"...\"}"
    fi

    local payload=$(jq -n \
        --arg model "$POWERAI_LOCAL_MODEL" \
        --arg sys "$sys_prompt" \
        --arg user "$query" \
        '{
            model: $model,
            stream: false,
            options: { temperature: 0.0 },
            messages: [
                { role: "system", content: $sys },
                { role: "user", content: $user }
            ]
        }')

    local res=$(curl -s -X POST "$POWERAI_OLLAMA_ENDPOINT/api/chat" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        --max-time 15)

    local parsed=$(_powerai_parse_response "$res")
    local cmd=$(echo "$parsed" | cut -f1)
    local exp=$(echo "$parsed" | cut -f2)

    if [[ "$cmd $exp" =~ $expected_pattern ]]; then
        echo "[PASS]"
        echo "    ↳ Comando: [$cmd]"
        echo "    ↳ Explicação: [$exp]"
        PASSED=$((PASSED + 1))
    else
        echo "[FAIL]"
        echo "    ↳ Esperado padrão: '$expected_pattern'"
        echo "    ↳ Obtido: Comando=[$cmd] | Explicação=[$exp]"
        FAILED=$((FAILED + 1))
    fi
    echo ""
}

# 1. Teste de Correção de Typo
run_ai_test "1. Correção de Typo ('mrdir kilo')" "mrdir kilo" true "mkdir[[:space:]]+kilo"

# 2. Teste de Consulta de Rede
run_ai_test "2. Consulta de Rede ('como listar portas escutando tcp')" "como listar portas escutando tcp" false "lsof|netstat|ss"

# 3. Teste de Busca com Filtro e Aspas
run_ai_test "3. Comando com Filtro ('filtrar linhas com erro no app.log')" "filtrar linhas com erro no app.log" false "grep"

# 4. Teste de Memória de Saída Contextual
POWERAI_SESSION_MEMORY=()
_powerai_add_session "ifconfig" "ifconfig" "en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 192.168.15.88 netmask 0xffffff00 broadcast 192.168.15.255"

run_ai_test "4. Memória de Saída ('qual é o meu ip local na saída acima?')" "qual é o meu ip local na saída acima?" false "192\.168\.15\.88"

# 5. Teste em Inglês
POWERAI_LANGUAGE="en-US"
run_ai_test "5. Idioma Inglês ('list all files sorted by size')" "list all files sorted by size" false "ls"

echo "=========================================================="
echo " Relatório Final de Autonomia:"
echo "   Testes Aprovados: $PASSED / $((PASSED + FAILED))"
echo "=========================================================="

if [ $FAILED -eq 0 ]; then
    echo " ✦ 100% DE AUTONOMIA PRESERVADA E OPERACIONAL!"
    exit 0
else
    echo " ⚠️ Alguns cenários falharam."
    exit 1
fi
