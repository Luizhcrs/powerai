using System;
using System.IO;
using System.Runtime.InteropServices;
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
                RestrictToOwner(ConfigPath);
            }
            catch { }
        }

        // config.json stores plaintext API keys; keep it readable only by
        // the owner on POSIX systems (Windows ACLs under the user profile
        // are already owner-only by default).
        private static void RestrictToOwner(string path)
        {
#if NET8_0_OR_GREATER
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) return;
            try
            {
                File.SetUnixFileMode(path, UnixFileMode.UserRead | UnixFileMode.UserWrite);
            }
            catch { }
#endif
        }
    }
}
