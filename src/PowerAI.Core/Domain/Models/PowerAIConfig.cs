using PowerAI.Core.Domain.Enums;

namespace PowerAI.Core.Domain.Models
{
    public class PowerAIConfig
    {
        public ProviderMode Mode { get; set; } = ProviderMode.Auto;
        public LocalProviderType LocalType { get; set; } = LocalProviderType.Ollama;
        public string LocalEndpoint { get; set; } = "http://127.0.0.1:5151/v1";
        public string LocalApiKey { get; set; } = string.Empty;
        public string LocalModel { get; set; } = "qwen2.5-coder:1.5b";
        public string OllamaEndpoint { get; set; } = "http://localhost:11434";
        public string CloudEndpoint { get; set; } = "https://api.openai.com/v1";
        public string CloudApiKey { get; set; } = string.Empty;
        public string CloudModel { get; set; } = "gpt-4o-mini";
        public bool AutoSuggestOnErrors { get; set; } = true;
        public int AutoHealingRetries { get; set; } = 2;
        public int TimeoutSeconds { get; set; } = 25;
    }
}
