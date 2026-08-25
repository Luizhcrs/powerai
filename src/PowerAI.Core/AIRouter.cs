using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using PowerAI.Core.Adapters.Outbound.Configuration;
using PowerAI.Core.Domain.Enums;
using PowerAI.Core.Domain.Models;
using PowerAI.Core.Ports.Inbound;

namespace PowerAI.Core
{
    // Re-export domain types in root namespace for seamless backwards compatibility
    public class PowerAIConfig : Domain.Models.PowerAIConfig { }
    public class SuggestionResult : Domain.Models.SuggestionResult { }

    public class AIRouter : IAIRouter
    {
        private readonly Application.AIRouter _innerRouter;

        public AIRouter(PowerAIConfig? config = null)
        {
            _innerRouter = new Application.AIRouter(config);
        }

        public Domain.Models.PowerAIConfig Config => _innerRouter.Config;

        public static string ConfigPath => new JsonConfigRepository().ConfigPath;

        public static PowerAIConfig LoadOrCreateConfig()
        {
            var cfg = new JsonConfigRepository().LoadOrCreate();
            return new PowerAIConfig
            {
                Mode = cfg.Mode,
                LocalType = cfg.LocalType,
                LocalEndpoint = cfg.LocalEndpoint,
                LocalApiKey = cfg.LocalApiKey,
                LocalModel = cfg.LocalModel,
                OllamaEndpoint = cfg.OllamaEndpoint,
                CloudEndpoint = cfg.CloudEndpoint,
                CloudApiKey = cfg.CloudApiKey,
                CloudModel = cfg.CloudModel,
                AutoSuggestOnErrors = cfg.AutoSuggestOnErrors,
                AutoHealingRetries = cfg.AutoHealingRetries,
                TimeoutSeconds = cfg.TimeoutSeconds
            };
        }

        public static void SaveConfig(Domain.Models.PowerAIConfig config)
        {
            new JsonConfigRepository().Save(config);
        }

        public Task<Domain.Models.SuggestionResult> FixErrorAsync(string command, string errorMessage, string cwd, string os = "Windows", CancellationToken ct = default)
        {
            return _innerRouter.FixErrorAsync(command, errorMessage, cwd, os, ct);
        }

        public Task<Domain.Models.SuggestionResult> ProcessIntentAsync(string query, string cwd, string os = "Windows", CancellationToken ct = default)
        {
            return _innerRouter.ProcessIntentAsync(query, cwd, os, ct);
        }
    }
}
