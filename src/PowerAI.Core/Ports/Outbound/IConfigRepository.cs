using PowerAI.Core.Domain.Models;

namespace PowerAI.Core.Ports.Outbound
{
    public interface IConfigRepository
    {
        string ConfigPath { get; }
        PowerAIConfig LoadOrCreate();
        void Save(PowerAIConfig config);
    }
}
