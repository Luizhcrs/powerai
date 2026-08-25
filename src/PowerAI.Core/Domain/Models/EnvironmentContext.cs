using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace PowerAI.Core.Domain.Models
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
            sb.AppendLine("[ENVIRONMENT CONTEXT]");
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
}
