# Module manifest for PowerAI
@{
    RootModule = 'PowerAI.psm1'
    ModuleVersion = '1.2.0'
    GUID = 'a84f3e58-69cb-4c54-8c81-bb0364f89d3a'
    Author = 'PowerAI'
    CompanyName = 'Community'
    Copyright = '(c) 2026. All rights reserved.'
    Description = 'Camada cognitiva transparente sobre o PowerShell com roteamento local-first (Ollama) e nuvem.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'ai',
        'Set-AIPowerShellProvider',
        'Get-AIPowerShellConfig',
        'Set-AIPowerShellConfig',
        'Invoke-AIErrorFix',
        'Invoke-AIRouterRequest',
        'Get-HarnessEnvironmentContext',
        'Parse-AIJsonResult',
        'Add-PowerAISessionTurn',
        'Get-PowerAISessionSummary',
        'Clear-PowerAISession',
        'Uninstall-PowerAI'
    )
    AliasesToExport = @('?')
    CmdletsToExport = @()
    VariablesToExport = @()
}
