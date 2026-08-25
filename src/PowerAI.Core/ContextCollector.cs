using PowerAI.Core.Domain.Models;
using PowerAI.Core.Ports.Inbound;

namespace PowerAI.Core
{
    public class EnvironmentContext : Domain.Models.EnvironmentContext { }

    public static class ContextCollector
    {
        private static readonly IContextCollector _instance = new Application.ContextCollector();

        public static Domain.Models.EnvironmentContext Collect(string cwd)
        {
            return _instance.Collect(cwd);
        }
    }
}
