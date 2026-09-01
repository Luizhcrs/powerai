using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using PowerAI.Core.Adapters.Outbound.Configuration;
using PowerAI.Core.Adapters.Outbound.Providers;
using PowerAI.Core.Domain.Enums;
using PowerAI.Core.Domain.Models;
using PowerAI.Core.Ports.Inbound;
using PowerAI.Core.Ports.Outbound;

namespace PowerAI.Core.Application
{
    public class AIRouter : IAIRouter
    {
        private readonly IConfigRepository _configRepo;
        private readonly HttpClient _httpClient;
        private readonly bool _configWasInjected;
        private PowerAIConfig _config;

        public AIRouter(PowerAIConfig? config = null, IConfigRepository? configRepo = null, HttpClient? httpClient = null)
        {
            _configRepo = configRepo ?? new JsonConfigRepository();
            _httpClient = httpClient ?? new HttpClient();
            _configWasInjected = config != null;
            _config = config ?? _configRepo.LoadOrCreate();
        }

        public PowerAIConfig Config => _config;

        public async Task<SuggestionResult> FixErrorAsync(string command, string errorMessage, string cwd, string os = "Windows", CancellationToken ct = default)
        {
            string systemPrompt =
                "You are an expert terminal assistant and CLI copilot. " +
                "The user executed a command that failed or is invalid. " +
                "Analyze what the user intended to do and provide the exact valid command to execute. " +
                "Respond strictly with a single JSON object with two fields:\n" +
                "\"suggested_command\": \"the exact command string\",\n" +
                "\"explanation\": \"short 1-sentence explanation in Portuguese of what was fixed\"\n" +
                "DO NOT wrap in markdown fences. Output only valid JSON.";

            string userPrompt =
                $"OS: {os}\n" +
                $"CWD: {cwd}\n" +
                $"Executed Command: {command}\n" +
                $"Error/Output: {errorMessage}\n\n" +
                "JSON:";

            return await ExecuteRoutedPromptAsync(systemPrompt, userPrompt, ct);
        }

        public async Task<SuggestionResult> ProcessIntentAsync(string query, string cwd, string os = "Windows", CancellationToken ct = default)
        {
            string systemPrompt =
                "You are an expert terminal assistant. The user wrote a natural language request or question in the shell. " +
                "Determine if there is an actionable command to execute for this request.\n" +
                "Respond strictly with a single JSON object:\n" +
                "{\n" +
                "  \"suggested_command\": \"the exact shell command to run, or null if it is purely informational\",\n" +
                "  \"explanation\": \"concise explanation or direct answer in Portuguese\"\n" +
                "}\n" +
                "DO NOT wrap in markdown fences. Output only valid JSON.";

            string userPrompt = $"OS: {os}\nCWD: {cwd}\nUser Input: {query}\n\nJSON:";

            return await ExecuteRoutedPromptAsync(systemPrompt, userPrompt, ct);
        }

        private async Task<SuggestionResult> ExecuteRoutedPromptAsync(string systemPrompt, string userPrompt, CancellationToken ct)
        {
            // Only reload from disk when the caller relied on the default
            // (no config passed to the constructor). An explicitly injected
            // config must be honored, not silently overwritten.
            if (!_configWasInjected)
            {
                _config = _configRepo.LoadOrCreate();
            }

            var ollamaProvider = new OllamaProvider(_httpClient, _config.OllamaEndpoint, _config.LocalModel, _config.TimeoutSeconds);
            var localOpenAIProvider = new OpenAICompatibleProvider(_httpClient, _config.LocalEndpoint, _config.LocalApiKey, _config.LocalModel, $"Local API ({_config.LocalModel})", _config.TimeoutSeconds);
            var cloudProvider = new OpenAICompatibleProvider(_httpClient, _config.CloudEndpoint, _config.CloudApiKey, _config.CloudModel, $"Cloud ({_config.CloudModel})", _config.TimeoutSeconds);

            ILLMProvider? primary = null;
            ILLMProvider? fallback = null;

            if (_config.Mode == ProviderMode.Local)
            {
                if (_config.LocalType == LocalProviderType.Ollama)
                {
                    primary = ollamaProvider;
                }
                else if (_config.LocalType == LocalProviderType.OpenAICompatible)
                {
                    primary = localOpenAIProvider;
                }
                else
                {
                    primary = await ollamaProvider.IsAvailableAsync(ct) ? (ILLMProvider)ollamaProvider : localOpenAIProvider;
                }
            }
            else if (_config.Mode == ProviderMode.Cloud)
            {
                primary = cloudProvider;
            }
            else // Auto Mode
            {
                if (await ollamaProvider.IsAvailableAsync(ct))
                {
                    primary = ollamaProvider;
                    fallback = !string.IsNullOrEmpty(_config.CloudApiKey) ? cloudProvider : null;
                }
                else if (await localOpenAIProvider.IsAvailableAsync(ct))
                {
                    primary = localOpenAIProvider;
                    fallback = !string.IsNullOrEmpty(_config.CloudApiKey) ? cloudProvider : null;
                }
                else if (!string.IsNullOrEmpty(_config.CloudApiKey))
                {
                    primary = cloudProvider;
                }
                else
                {
                    return new SuggestionResult
                    {
                        Success = false,
                        Explanation = "Nenhum provedor de IA disponível (Ollama/Local API offline e CloudApiKey não configurada)."
                    };
                }
            }

            if (primary != null)
            {
                try
                {
                    var (success, content) = await primary.QueryAsync(systemPrompt, userPrompt, ct);
                    if (success)
                    {
                        return ParseResult(content, primary.ProviderName);
                    }
                }
                catch (Exception ex)
                {
                    if (fallback != null)
                    {
                        try
                        {
                            var (fSuccess, fContent) = await fallback.QueryAsync(systemPrompt, userPrompt, ct);
                            if (fSuccess)
                            {
                                return ParseResult(fContent, $"{fallback.ProviderName} (Fallback)");
                            }
                        }
                        catch { }
                    }

                    return new SuggestionResult
                    {
                        Success = false,
                        Explanation = $"Erro no provedor {primary.ProviderName}: {ex.Message}"
                    };
                }
            }

            return new SuggestionResult
            {
                Success = false,
                Explanation = "Falha ao executar consulta com o provedor configurado."
            };
        }

        private SuggestionResult ParseResult(string rawContent, string provider)
        {
            rawContent = rawContent.Trim();

            int firstBrace = rawContent.IndexOf('{');
            int lastBrace = rawContent.LastIndexOf('}');
            string jsonCandidate = (firstBrace >= 0 && lastBrace > firstBrace)
                ? rawContent.Substring(firstBrace, (lastBrace - firstBrace) + 1)
                : rawContent;

            try
            {
                using var doc = JsonDocument.Parse(jsonCandidate);
                string? cmd = null;
                string? exp = null;

                if (doc.RootElement.TryGetProperty("suggested_command", out var cmdProp) && cmdProp.ValueKind == JsonValueKind.String)
                {
                    cmd = cmdProp.GetString();
                }
                if (doc.RootElement.TryGetProperty("explanation", out var expProp) && expProp.ValueKind == JsonValueKind.String)
                {
                    exp = expProp.GetString();
                }

                return new SuggestionResult
                {
                    Success = true,
                    SuggestedCommand = string.IsNullOrWhiteSpace(cmd) || cmd.Equals("null", StringComparison.OrdinalIgnoreCase) ? null : cmd,
                    Explanation = exp,
                    RawResponse = rawContent,
                    ProviderUsed = provider
                };
            }
            catch
            {
                return new SuggestionResult
                {
                    Success = true,
                    RawResponse = rawContent,
                    Explanation = rawContent,
                    ProviderUsed = provider
                };
            }
        }
    }
}
