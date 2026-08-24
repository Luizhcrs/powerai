using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;

namespace PowerAI.Core
{
    public class EnvironmentContext
    {
        public string Cwd { get; set; } = string.Empty;
        public string OsVersion { get; set; } = string.Empty;
        public List<string> TopLevelFiles { get; set; } = new List<string>();
        public List<string> TopLevelDirs { get; set; } = new List<string>();
        public string? GitBranch { get; set; }
        public string? GitStatusShort { get; set; }
        public string? ProjectType { get; set; }

        public string ToContextSummary()
        {
            var sb = new StringBuilder();
            sb.AppendLine($"[ENVIRONMENT CONTEXT]");
            sb.AppendLine($"- CWD: {Cwd}");
            sb.AppendLine($"- OS: {OsVersion}");
            if (!string.IsNullOrEmpty(ProjectType))
            {
                sb.AppendLine($"- Detected Project Type: {ProjectType}");
            }
            if (!string.IsNullOrEmpty(GitBranch))
            {
                sb.AppendLine($"- Git Branch: {GitBranch}");
            }
            if (TopLevelDirs.Count > 0)
            {
                sb.AppendLine($"- Subdirectories: {string.Join(", ", TopLevelDirs.Take(10))}");
            }
            if (TopLevelFiles.Count > 0)
            {
                sb.AppendLine($"- Key Files: {string.Join(", ", TopLevelFiles.Take(15))}");
            }
            return sb.ToString();
        }
    }

    public static class ContextCollector
    {
        public static EnvironmentContext Collect(string cwd)
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
                    ctx.GitBranch = RunCliCommand("git", "rev-parse --abbrev-ref HEAD", cwd)?.Trim();
                }
            }
            catch { }

            return ctx;
        }

        private static string? RunCliCommand(string executable, string args, string cwd)
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = executable,
                    Arguments = args,
                    WorkingDirectory = cwd,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var proc = Process.Start(psi);
                if (proc == null) return null;
                string output = proc.StandardOutput.ReadToEnd();
                proc.WaitForExit(1000);
                return output;
            }
            catch
            {
                return null;
            }
        }
    }
}
