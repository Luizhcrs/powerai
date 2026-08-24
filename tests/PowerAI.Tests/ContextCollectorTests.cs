using System.IO;
using PowerAI.Core;
using Xunit;

namespace PowerAI.Tests
{
    public class ContextCollectorTests
    {
        [Fact]
        public void Collect_ShouldDetectCurrentDirectoryAndFiles()
        {
            // Arrange
            string cwd = Directory.GetCurrentDirectory();

            // Act
            var context = ContextCollector.Collect(cwd);

            // Assert
            Assert.NotNull(context);
            Assert.Equal(cwd, context.Cwd);
            Assert.False(string.IsNullOrEmpty(context.OsVersion));
        }

        [Fact]
        public void ToContextSummary_ShouldContainEssentialHeaders()
        {
            // Arrange
            var ctx = new EnvironmentContext
            {
                Cwd = @"C:\Projetos\App",
                OsVersion = "Microsoft Windows 11",
                ProjectType = "Node.js"
            };
            ctx.TopLevelFiles.Add("package.json");
            ctx.TopLevelDirs.Add("src");

            // Act
            string summary = ctx.ToContextSummary();

            // Assert
            Assert.Contains("[ENVIRONMENT CONTEXT]", summary);
            Assert.Contains("Node.js", summary);
            Assert.Contains("package.json", summary);
            Assert.Contains("src", summary);
        }

        [Fact]
        public void Config_ShouldSerializeAndDeserializeProperly()
        {
            // Arrange
            var config = new PowerAIConfig
            {
                Mode = ProviderMode.Local,
                LocalModel = "qwen2.5-coder:1.5b",
                TimeoutSeconds = 15
            };

            // Act
            var json = System.Text.Json.JsonSerializer.Serialize(config);
            var deserialized = System.Text.Json.JsonSerializer.Deserialize<PowerAIConfig>(json);

            // Assert
            Assert.NotNull(deserialized);
            Assert.Equal(ProviderMode.Local, deserialized.Mode);
            Assert.Equal("qwen2.5-coder:1.5b", deserialized.LocalModel);
            Assert.Equal(15, deserialized.TimeoutSeconds);
        }
    }
}
