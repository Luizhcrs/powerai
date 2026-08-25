using PowerAI.Core.Domain.Models;

namespace PowerAI.Core.Ports.Inbound
{
    public interface IContextCollector
    {
        EnvironmentContext Collect(string cwd);
    }
}
