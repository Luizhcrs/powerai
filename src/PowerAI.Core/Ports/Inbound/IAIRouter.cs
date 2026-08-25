using System.Threading;
using System.Threading.Tasks;
using PowerAI.Core.Domain.Models;

namespace PowerAI.Core.Ports.Inbound
{
    public interface IAIRouter
    {
        PowerAIConfig Config { get; }
        Task<SuggestionResult> FixErrorAsync(string command, string errorMessage, string cwd, string os = "Windows", CancellationToken ct = default);
        Task<SuggestionResult> ProcessIntentAsync(string query, string cwd, string os = "Windows", CancellationToken ct = default);
    }
}
