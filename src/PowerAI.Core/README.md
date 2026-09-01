# PowerAI.Core

Biblioteca C# (arquitetura hexagonal: `AIRouter`, `ContextCollector`,
`JsonConfigRepository`, providers de Ollama/OpenAI-compatible) com cobertura
de testes própria em `tests/PowerAI.Tests`.

## Status: não referenciada pelo módulo distribuído

O módulo que os usuários realmente instalam no Windows
(`src/PowerAI/PowerAI.psm1`, declarado como `RootModule` em
`PowerAI.psd1`) **não depende de `PowerAI.Core.dll`**. Ele reimplementa,
em PowerShell puro, toda a lógica de roteamento de provedor, leitura de
configuração e coleta de contexto que já existe aqui.

Isso significa que:

- Bugs corrigidos em `PowerAI.Core` (ex.: `AIRouter` ignorando a config
  injetada no construtor) **não chegam a nenhum usuário final** até que
  este código seja de fato consumido por algo distribuído.
- Existem hoje duas implementações paralelas da mesma lógica (roteamento
  de provedor, parsing de JSON, etc.) — uma em C#, outra em
  `PowerAI.psm1` — com risco real de divergência quando uma delas for
  corrigida ou ganhar uma funcionalidade nova e a outra não.

Antes de investir mais trabalho aqui, decidir um destes caminhos:

1. Fazer o módulo PowerShell consumir `PowerAI.Core.dll` (via
   `Add-Type` / assembly load) e remover a lógica duplicada de
   `PowerAI.psm1`.
2. Assumir que este projeto é uma base para uma futura interface nativa
   (CLI/binário) separada do módulo PowerShell, e documentar isso
   explicitamente no `README.md` raiz do repositório.
3. Remover a biblioteca se nenhum dos dois planos acima for viável.
