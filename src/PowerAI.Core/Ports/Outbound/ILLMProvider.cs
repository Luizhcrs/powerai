using System.Threading;
using System.Threading.Tasks;

namespace PowerAI.Core.Ports.Outbound
{
    public interface ILLMProvider
    {
        string ProviderName { get; }
        Task<bool> IsAvailableAsync(CancellationToken ct = default);
        Task<(bool Success, string Content)> QueryAsync(string systemPrompt, string userPrompt, CancellationToken ct = default);
    }
}
