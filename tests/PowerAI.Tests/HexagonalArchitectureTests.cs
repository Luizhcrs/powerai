using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using PowerAI.Core.Adapters.Outbound.Configuration;
using PowerAI.Core.Adapters.Outbound.Providers;
using PowerAI.Core.Domain.Enums;
using PowerAI.Core.Domain.Models;
using PowerAI.Core.Ports.Outbound;
using Xunit;

namespace PowerAI.Tests
{
    public class MockHttpMessageHandler : HttpMessageHandler
    {
        private readonly Func<HttpRequestMessage, HttpResponseMessage> _handler;

        public MockHttpMessageHandler(Func<HttpRequestMessage, HttpResponseMessage> handler)
        {
            _handler = handler;
        }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            return Task.FromResult(_handler(request));
        }
    }

    public class HexagonalArchitectureTests
    {
        [Fact]
        public async Task OllamaProvider_ShouldParseValidResponse()
        {
            var mockHandler = new MockHttpMessageHandler(req =>
            {
                var json = "{\"message\": {\"content\": \"{\\\"suggested_command\\\": \\\"df -h\\\", \\\"explanation\\\": \\\"Mostra espaco em disco\\\"}\"}}";
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(json, Encoding.UTF8, "application/json")
                };
            });

            var httpClient = new HttpClient(mockHandler);
            var provider = new OllamaProvider(httpClient, "http://localhost:11434", "qwen2.5-coder:1.5b");

            var (success, content) = await provider.QueryAsync("system prompt", "user query");

            Assert.True(success);
            Assert.Contains("df -h", content);
            Assert.Contains("Mostra espaco em disco", content);
            Assert.Equal("Ollama (qwen2.5-coder:1.5b)", provider.ProviderName);
        }

        [Fact]
        public async Task OpenAICompatibleProvider_ShouldParseChoicesResponse()
        {
            var mockHandler = new MockHttpMessageHandler(req =>
            {
                var json = "{\"choices\": [{\"message\": {\"content\": \"{\\\"suggested_command\\\": \\\"lsof -i :8080\\\", \\\"explanation\\\": \\\"Verifica porta 8080\\\"}\"}}]}";
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(json, Encoding.UTF8, "application/json")
                };
            });

            var httpClient = new HttpClient(mockHandler);
            var provider = new OpenAICompatibleProvider(httpClient, "http://127.0.0.1:5151/v1", "sk-test", "qwen2.5-7b", "Local OMLX");

            var (success, content) = await provider.QueryAsync("system prompt", "user query");

            Assert.True(success);
            Assert.Contains("lsof -i :8080", content);
            Assert.Equal("Local OMLX", provider.ProviderName);
        }

        [Fact]
        public async Task AIRouter_ShouldOrchestrateAndParseSuggestionResult()
        {
            var mockHandler = new MockHttpMessageHandler(req =>
            {
                if (req.RequestUri!.AbsolutePath.Contains("/api/tags") || req.RequestUri.AbsolutePath.Contains("/models"))
                {
                    return new HttpResponseMessage(HttpStatusCode.OK);
                }

                var json = "{\"message\": {\"content\": \"{\\\"suggested_command\\\": \\\"git status\\\", \\\"explanation\\\": \\\"Verifica status do repositorio\\\"}\"}}";
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(json, Encoding.UTF8, "application/json")
                };
            });

            var httpClient = new HttpClient(mockHandler);
            var config = new PowerAIConfig
            {
                Mode = ProviderMode.Local,
                LocalType = LocalProviderType.Ollama,
                LocalModel = "qwen2.5-coder:1.5b"
            };

            var router = new PowerAI.Core.Application.AIRouter(config, httpClient: httpClient);
            var result = await router.ProcessIntentAsync("como ver status do git", "C:\\Projetos");

            Assert.NotNull(result);
            Assert.True(result.Success);
            Assert.Equal("git status", result.SuggestedCommand);
            Assert.Equal("Verifica status do repositorio", result.Explanation);
        }

        [Fact]
        public void BackwardCompatibility_RootNamespaceFacade_ShouldMatchPublicApi()
        {
            // Verify that root namespace types work identically
            var rootConfig = new PowerAI.Core.PowerAIConfig
            {
                LocalModel = "qwen2.5-coder:1.5b"
            };

            var rootRouter = new PowerAI.Core.AIRouter(rootConfig);
            Assert.NotNull(rootRouter.Config);
            Assert.Equal("qwen2.5-coder:1.5b", rootRouter.Config.LocalModel);
            Assert.False(string.IsNullOrEmpty(PowerAI.Core.AIRouter.ConfigPath));
        }
    }
}
