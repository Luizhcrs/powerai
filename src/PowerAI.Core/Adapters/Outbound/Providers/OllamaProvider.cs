using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using PowerAI.Core.Ports.Outbound;

namespace PowerAI.Core.Adapters.Outbound.Providers
{
    public class OllamaProvider : ILLMProvider
    {
        private readonly HttpClient _httpClient;
        private readonly string _endpoint;
        private readonly string _model;
        private readonly int _timeoutSeconds;

        public OllamaProvider(HttpClient httpClient, string endpoint, string model, int timeoutSeconds = 25)
        {
            _httpClient = httpClient;
            _endpoint = (endpoint ?? "http://localhost:11434").TrimEnd('/');
            _model = model ?? "qwen2.5-coder:1.5b";
            _timeoutSeconds = timeoutSeconds > 0 ? timeoutSeconds : 25;
        }

        public string ProviderName => $"Ollama ({_model})";

        public async Task<bool> IsAvailableAsync(CancellationToken ct = default)
        {
            try
            {
                using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
                cts.CancelAfter(TimeSpan.FromSeconds(2.0));
                var response = await _httpClient.GetAsync($"{_endpoint}/api/tags", cts.Token);
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        public async Task<(bool Success, string Content)> QueryAsync(string systemPrompt, string userPrompt, CancellationToken ct = default)
        {
            var url = $"{_endpoint}/api/chat";
            var requestBody = new
            {
                model = _model,
                stream = false,
                messages = new[]
                {
                    new { role = "system", content = systemPrompt },
                    new { role = "user", content = userPrompt }
                },
                options = new
                {
                    temperature = 0.0
                }
            };

            using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            cts.CancelAfter(TimeSpan.FromSeconds(_timeoutSeconds));

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
                return (true, text.GetString() ?? string.Empty);
            }

            return (false, "Resposta inválida do Ollama");
        }
    }
}
