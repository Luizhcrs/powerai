using System;
using System.IO;
using System.Text.Json;
using PowerAI.Core.Domain.Models;
using PowerAI.Core.Ports.Outbound;

namespace PowerAI.Core.Adapters.Outbound.Configuration
{
    public class JsonConfigRepository : IConfigRepository
    {
        private static readonly JsonSerializerOptions JsonOptions = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNameCaseInsensitive = true
        };

        public string ConfigPath =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".powerai", "config.json");

        public PowerAIConfig LoadOrCreate()
        {
            try
            {
                if (File.Exists(ConfigPath))
                {
                    var json = File.ReadAllText(ConfigPath);
                    var cfg = JsonSerializer.Deserialize<PowerAIConfig>(json, JsonOptions);
                    if (cfg != null) return cfg;
                }
            }
            catch { }

            var newConfig = new PowerAIConfig();
            Save(newConfig);
            return newConfig;
        }

        public void Save(PowerAIConfig config)
        {
            try
            {
                var dir = Path.GetDirectoryName(ConfigPath);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                {
                    Directory.CreateDirectory(dir);
                }
                var json = JsonSerializer.Serialize(config, JsonOptions);
                File.WriteAllText(ConfigPath, json);
            }
            catch { }
        }
    }
}
