using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace PowerAI.Core
{
    public enum ProviderMode
    {
        Auto,
        Local,
        Cloud
    }

    public class PowerAIConfig
    {
        public ProviderMode Mode { get; set; } = ProviderMode.Auto;
        public string OllamaEndpoint { get; set; } = "http://localhost:11434";
        public string LocalModel { get; set; } = "qwen2.5:3b";
        public string CloudEndpoint { get; set; } = "https://api.openai.com/v1";
        public string CloudApiKey { get; set; } = string.Empty;
        public string CloudModel { get; set; } = "gpt-4o-mini";
        public bool AutoSuggestOnErrors { get; set; } = true;
        public int TimeoutSeconds { get; set; } = 30;
    }

    public class SuggestionResult
    {
        public bool Success { get; set; }
        public string? SuggestedCommand { get; set; }
        public string? Explanation { get; set; }
        public string? RawResponse { get; set; }
        public string? ProviderUsed { get; set; }
    }

    public class AIRouter
    {
        private readonly PowerAIConfig _config;
        private static readonly HttpClient _httpClient = new HttpClient();

        public AIRouter(PowerAIConfig? config = null)
        {
            _config = config ?? LoadOrCreateConfig();
        }

        public PowerAIConfig Config => _config;

        public static string ConfigPath =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".powerai", "config.json");

        public static PowerAIConfig LoadOrCreateConfig()
        {
            try
            {
                if (File.Exists(ConfigPath))
                {
                    var json = File.ReadAllText(ConfigPath);
                    var cfg = JsonSerializer.Deserialize<PowerAIConfig>(json);
                    if (cfg != null) return cfg;
                }
            }
            catch { }

            var newConfig = new PowerAIConfig();
            SaveConfig(newConfig);
            return newConfig;
        }

        public static void SaveConfig(PowerAIConfig config)
        {
            try
            {
                var dir = Path.GetDirectoryName(ConfigPath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                {
                    Directory.CreateDirectory(dir);
                }
                var json = JsonSerializer.Serialize(config, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(ConfigPath, json);
            }
            catch { }
        }

        public async Task<bool> IsOllamaAvailableAsync()
        {
            try
            {
                using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(2.0));
                var response = await _httpClient.GetAsync($"{_config.OllamaEndpoint}/api/tags", cts.Token);
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        public async Task<SuggestionResult> FixErrorAsync(string command, string errorMessage, string cwd, string os = "Windows")
        {
            string systemPrompt = 
                "You are an expert PowerShell and terminal assistant. " +
                "The user executed a command in PowerShell that failed or is invalid. " +
                "Infer what the user intended to do and provide the exact valid command to execute. " +
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

            return await ExecuteRoutedPromptAsync(systemPrompt, userPrompt, isSimple: true);
        }

        public async Task<SuggestionResult> ProcessIntentAsync(string query, string cwd, string os = "Windows")
        {
            string systemPrompt = 
                "You are an expert terminal assistant. The user wrote a natural language request or question in PowerShell. " +
                "Determine if there is an actionable command to execute for this request.\n" +
                "Respond strictly with a single JSON object:\n" +
                "{\n" +
                "  \"suggested_command\": \"the exact PowerShell command to run, or null if it is purely informational with no single command\",\n" +
                "  \"explanation\": \"concise explanation or answer in Portuguese\"\n" +
                "}\n" +
                "DO NOT wrap in markdown fences. Output only valid JSON.";

            string userPrompt = $"OS: {os}\nCWD: {cwd}\nUser Input: {query}\n\nJSON:";

            return await ExecuteRoutedPromptAsync(systemPrompt, userPrompt, isSimple: false);
        }

        private async Task<SuggestionResult> ExecuteRoutedPromptAsync(string systemPrompt, string userPrompt, bool isSimple)
        {
            // Reload config dynamically in case user edited config.json
            var liveConfig = LoadOrCreateConfig();
            _config.Mode = liveConfig.Mode;
            _config.LocalModel = liveConfig.LocalModel;
            _config.CloudApiKey = liveConfig.CloudApiKey;
            _config.CloudModel = liveConfig.CloudModel;

            bool useLocal = false;

            if (_config.Mode == ProviderMode.Local)
            {
                useLocal = true;
            }
            else if (_config.Mode == ProviderMode.Cloud)
            {
                useLocal = false;
            }
            else // Auto
            {
                bool ollamaUp = await IsOllamaAvailableAsync();
                if (ollamaUp)
                {
                    useLocal = true;
                }
                else if (!string.IsNullOrEmpty(_config.CloudApiKey))
                {
                    useLocal = false;
                }
                else
                {
                    return new SuggestionResult
                    {
                        Success = false,
                        Explanation = "Nenhum provedor de IA disponível (Ollama offline e chave Cloud não configurada)."
                    };
                }
            }

            if (useLocal)
            {
                try
                {
                    var (success, content) = await QueryOllamaAsync(systemPrompt, userPrompt);
                    if (success)
                    {
                        return ParseResult(content, "Ollama (" + _config.LocalModel + ")");
                    }
                }
                catch (Exception ex)
                {
                    if (_config.Mode == ProviderMode.Auto && !string.IsNullOrEmpty(_config.CloudApiKey))
                    {
                        var (cloudSuccess, cloudContent) = await QueryOpenAIAsync(systemPrompt, userPrompt);
                        if (cloudSuccess) return ParseResult(cloudContent, "Cloud OpenAI Fallback");
                    }
                    return new SuggestionResult { Success = false, Explanation = $"Erro Ollama: {ex.Message}" };
                }
            }

            if (!string.IsNullOrEmpty(_config.CloudApiKey))
            {
                try
                {
                    var (success, content) = await QueryOpenAIAsync(systemPrompt, userPrompt);
                    if (success)
                    {
                        return ParseResult(content, "Cloud (" + _config.CloudModel + ")");
                    }
                }
                catch (Exception ex)
                {
                    return new SuggestionResult { Success = false, Explanation = $"Erro Cloud: {ex.Message}" };
                }
            }

            return new SuggestionResult
            {
                Success = false,
                Explanation = "Provedor Cloud selecionado, mas CloudApiKey não configurada em ~/.powerai/config.json"
            };
        }

        private async Task<(bool success, string content)> QueryOllamaAsync(string systemPrompt, string userPrompt)
        {
            var url = $"{_config.OllamaEndpoint}/api/chat";
            var requestBody = new
            {
                model = _config.LocalModel,
                stream = false,
                messages = new[]
                {
                    new { role = "system", content = systemPrompt },
                    new { role = "user", content = userPrompt }
                },
                options = new
                {
                    temperature = 0.2
                }
            };

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(_config.TimeoutSeconds));
            var json = JsonSerializer.Serialize(requestBody);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var resp = await _httpClient.PostAsync(url, content, cts.Token);
            if (!resp.IsSuccessStatusCode)
            {
                return (false, $"HTTP {resp.StatusCode}");
            }

            var respJson = await resp.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(respJson);
            if (doc.RootElement.TryGetProperty("message", out var msg) &&
                msg.TryGetProperty("content", out var text))
            {
                return (true, text.GetString() ?? "");
            }

            return (false, "Resposta inválida do Ollama");
        }

        private async Task<(bool success, string content)> QueryOpenAIAsync(string systemPrompt, string userPrompt)
        {
            var url = $"{_config.CloudEndpoint.TrimEnd('/')}/chat/completions";
            var requestBody = new
            {
                model = _config.CloudModel,
                messages = new[]
                {
                    new { role = "system", content = systemPrompt },
                    new { role = "user", content = userPrompt }
                },
                temperature = 0.2
            };

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(_config.TimeoutSeconds));
            using var req = new HttpRequestMessage(HttpMethod.Post, url);
            req.Headers.Add("Authorization", $"Bearer {_config.CloudApiKey}");
            req.Content = new StringContent(JsonSerializer.Serialize(requestBody), Encoding.UTF8, "application/json");

            var resp = await _httpClient.SendAsync(req, cts.Token);
            if (!resp.IsSuccessStatusCode)
            {
                return (false, $"HTTP {resp.StatusCode}");
            }

            var respJson = await resp.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(respJson);
            if (doc.RootElement.TryGetProperty("choices", out var choices) &&
                choices.GetArrayLength() > 0)
            {
                var firstChoice = choices[0];
                if (firstChoice.TryGetProperty("message", out var msg) &&
                    msg.TryGetProperty("content", out var text))
                {
                    return (true, text.GetString() ?? "");
                }
            }

            return (false, "Resposta inválida da OpenAI");
        }

        private SuggestionResult ParseResult(string rawContent, string provider)
        {
            rawContent = rawContent.Trim();
            
            // Extract JSON substring if surrounded by extra text or markdown
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
                    SuggestedCommand = string.IsNullOrWhiteSpace(cmd) ? null : cmd,
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
