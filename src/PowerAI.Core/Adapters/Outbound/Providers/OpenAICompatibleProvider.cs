using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using PowerAI.Core.Ports.Outbound;

namespace PowerAI.Core.Adapters.Outbound.Providers
{
    public class OpenAICompatibleProvider : ILLMProvider
    {
        private readonly HttpClient _httpClient;
        private readonly string _endpoint;
        private readonly string _apiKey;
        private readonly string _model;
        private readonly string _displayName;
        private readonly int _timeoutSeconds;

        public OpenAICompatibleProvider(
            HttpClient httpClient, 
            string endpoint, 
            string apiKey, 
            string model, 
            string? displayName = null, 
            int timeoutSeconds = 25)
        {
            _httpClient = httpClient;
            _endpoint = (endpoint ?? string.Empty).TrimEnd('/');
            _apiKey = apiKey ?? string.Empty;
            _model = model ?? string.Empty;
            _displayName = displayName ?? $"OpenAI-Compatible ({_model})";
            _timeoutSeconds = timeoutSeconds > 0 ? timeoutSeconds : 25;
        }

        public string ProviderName => _displayName;

        public async Task<bool> IsAvailableAsync(CancellationToken ct = default)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(_endpoint)) return false;
                var url = $"{_endpoint}/models";
                using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
                cts.CancelAfter(TimeSpan.FromSeconds(2.0));
                using var req = new HttpRequestMessage(HttpMethod.Get, url);
                if (!string.IsNullOrWhiteSpace(_apiKey))
                {
                    req.Headers.Add("Authorization", $"Bearer {_apiKey}");
                }
                var response = await _httpClient.SendAsync(req, cts.Token);
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        public async Task<(bool Success, string Content)> QueryAsync(string systemPrompt, string userPrompt, CancellationToken ct = default)
        {
            var url = _endpoint.EndsWith("/chat/completions", StringComparison.OrdinalIgnoreCase)
                ? _endpoint
                : $"{_endpoint}/chat/completions";

            var requestBody = new
            {
                model = _model,
                temperature = 0.0,
                messages = new[]
                {
                    new { role = "system", content = systemPrompt },
                    new { role = "user", content = userPrompt }
                }
            };

            using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            cts.CancelAfter(TimeSpan.FromSeconds(_timeoutSeconds));
            using var req = new HttpRequestMessage(HttpMethod.Post, url);
            if (!string.IsNullOrWhiteSpace(_apiKey))
            {
                req.Headers.Add("Authorization", $"Bearer {_apiKey}");
            }
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
                    return (true, text.GetString() ?? string.Empty);
                }
            }

            return (false, "Resposta inválida da API");
        }
    }
}
