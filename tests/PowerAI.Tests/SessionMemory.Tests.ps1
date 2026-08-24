# Isolated PowerShell Module Unit Tests
Import-Module "$PSScriptRoot\..\..\src\PowerAI\PowerAI.psd1" -Force

Describe "PowerAI Session Memory & Harness Tests" {
    BeforeEach {
        Clear-PowerAISession
    }

    It "Should start with empty session history" {
        $history = Get-PowerAISessionSummary
        $history | Should -Be "Nenhum histórico na sessão atual."
    }

    It "Should record session turns into volatile memory" {
        Add-PowerAISessionTurn -UserQuery "listar arquivos" -SuggestedCommand "Get-ChildItem -File" -Explanation "Lista arquivos"
        $history = Get-PowerAISessionSummary
        $history | Should -Match "listar arquivos"
        $history | Should -Match "Get-ChildItem -File"
    }

    It "Should clear session memory on command" {
        Add-PowerAISessionTurn -UserQuery "comando teste" -SuggestedCommand "echo 1" -Explanation "teste"
        Clear-PowerAISession
        $history = Get-PowerAISessionSummary
        $history | Should -Be "Nenhum histórico na sessão atual."
    }

    It "Should collect local directory structure into Harness context" {
        $ctx = Get-HarnessEnvironmentContext -Cwd (Get-Location).Path
        $ctx | Should -Match "=== CONTEXTO DO AMBIENTE ==="
        $ctx | Should -Match "Diretório Atual"
    }
}
