using System;
using System.Text.Json;
using PowerAI.Core.Domain.Enums;
using PowerAI.Core.Domain.Models;
using Xunit;

namespace PowerAI.Tests
{
    public class DomainTests
    {
        [Fact]
        public void PowerAIConfig_ShouldHaveValidDefaultValues()
        {
            var config = new PowerAIConfig();

            Assert.Equal(ProviderMode.Auto, config.Mode);
            Assert.Equal(LocalProviderType.Ollama, config.LocalType);
            Assert.Equal("http://localhost:11434", config.OllamaEndpoint);
            Assert.Equal("http://127.0.0.1:5151/v1", config.LocalEndpoint);
            Assert.Equal("qwen2.5-coder:1.5b", config.LocalModel);
            Assert.Equal("gpt-4o-mini", config.CloudModel);
            Assert.True(config.AutoSuggestOnErrors);
            Assert.Equal(2, config.AutoHealingRetries);
            Assert.True(config.TimeoutSeconds > 0);
        }

        [Fact]
        public void PowerAIConfig_ShouldSerializeAndDeserializeCorrectly()
        {
            var config = new PowerAIConfig
            {
                Mode = ProviderMode.Local,
                LocalType = LocalProviderType.OpenAICompatible,
                LocalEndpoint = "http://127.0.0.1:8000/v1",
                LocalApiKey = "sk-test-123",
                LocalModel = "custom-model:7b",
                AutoSuggestOnErrors = false,
                TimeoutSeconds = 45
            };

            var json = JsonSerializer.Serialize(config, new JsonSerializerOptions { WriteIndented = true });
            var deserialized = JsonSerializer.Deserialize<PowerAIConfig>(json);

            Assert.NotNull(deserialized);
            Assert.Equal(ProviderMode.Local, deserialized.Mode);
            Assert.Equal(LocalProviderType.OpenAICompatible, deserialized.LocalType);
            Assert.Equal("http://127.0.0.1:8000/v1", deserialized.LocalEndpoint);
            Assert.Equal("sk-test-123", deserialized.LocalApiKey);
            Assert.Equal("custom-model:7b", deserialized.LocalModel);
            Assert.False(deserialized.AutoSuggestOnErrors);
            Assert.Equal(45, deserialized.TimeoutSeconds);
        }

        [Fact]
        public void SuggestionResult_ShouldStorePropertiesProperly()
        {
            var result = new SuggestionResult
            {
                Success = true,
                SuggestedCommand = "ls -la",
                Explanation = "Lista arquivos detalhados",
                ProviderUsed = "Ollama (qwen2.5-coder:1.5b)",
                RawResponse = "{\"suggested_command\": \"ls -la\", \"explanation\": \"Lista arquivos detalhados\"}"
            };

            Assert.True(result.Success);
            Assert.Equal("ls -la", result.SuggestedCommand);
            Assert.Equal("Lista arquivos detalhados", result.Explanation);
            Assert.Equal("Ollama (qwen2.5-coder:1.5b)", result.ProviderUsed);
        }

        [Fact]
        public void SessionTurn_ShouldRecordTurnMetadata()
        {
            var turn = new SessionTurn
            {
                TurnNumber = 1,
                Query = "como ver ip",
                SuggestedCommand = "ifconfig",
                Explanation = "Mostra configuracao de rede",
                TerminalOutput = "en0: 192.168.0.100"
            };

            Assert.Equal(1, turn.TurnNumber);
            Assert.Equal("como ver ip", turn.Query);
            Assert.Equal("ifconfig", turn.SuggestedCommand);
            Assert.Contains("192.168.0.100", turn.TerminalOutput);
            Assert.True(turn.Timestamp <= DateTime.UtcNow);
        }
    }
}
