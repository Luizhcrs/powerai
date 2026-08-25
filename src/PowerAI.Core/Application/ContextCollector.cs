using System;
using System.IO;
using System.Linq;
using PowerAI.Core.Adapters.Outbound.Cli;
using PowerAI.Core.Domain.Models;
using PowerAI.Core.Ports.Inbound;
using PowerAI.Core.Ports.Outbound;

namespace PowerAI.Core.Application
{
    public class ContextCollector : IContextCollector
    {
        private readonly ICliExecutor _cliExecutor;

        public ContextCollector(ICliExecutor? cliExecutor = null)
        {
            _cliExecutor = cliExecutor ?? new ProcessCliExecutor();
        }

        public EnvironmentContext Collect(string cwd)
        {
            var ctx = new EnvironmentContext
            {
                Cwd = cwd,
                OsVersion = Environment.OSVersion.VersionString
            };

            try
            {
                if (Directory.Exists(cwd))
                {
                    var dirInfo = new DirectoryInfo(cwd);
                    ctx.TopLevelDirs = dirInfo.GetDirectories()
                        .Where(d => !d.Name.StartsWith(".") && d.Name != "node_modules" && d.Name != "bin" && d.Name != "obj")
                        .Select(d => d.Name)
                        .ToList();

                    ctx.TopLevelFiles = dirInfo.GetFiles()
                        .Where(f => !f.Name.StartsWith("."))
                        .Select(f => f.Name)
                        .ToList();

                    // Detect project type
                    if (ctx.TopLevelFiles.Contains("package.json")) ctx.ProjectType = "Node.js / JavaScript / TypeScript";
                    else if (ctx.TopLevelFiles.Any(f => f.EndsWith(".csproj") || f.EndsWith(".sln"))) ctx.ProjectType = ".NET / C#";
                    else if (ctx.TopLevelFiles.Contains("requirements.txt") || ctx.TopLevelFiles.Contains("pyproject.toml")) ctx.ProjectType = "Python";
                    else if (ctx.TopLevelFiles.Contains("Cargo.toml")) ctx.ProjectType = "Rust";
                    else if (ctx.TopLevelFiles.Contains("go.mod")) ctx.ProjectType = "Go";
                }
            }
            catch { }

            // Collect Git Status if repository
            try
            {
                if (Directory.Exists(Path.Combine(cwd, ".git")))
                {
                    ctx.GitBranch = _cliExecutor.ExecuteCommand("git", "rev-parse --abbrev-ref HEAD", cwd)?.Trim();
                }
            }
            catch { }

            return ctx;
        }
    }
}
