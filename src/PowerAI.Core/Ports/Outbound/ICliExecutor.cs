namespace PowerAI.Core.Ports.Outbound
{
    public interface ICliExecutor
    {
        string? ExecuteCommand(string executable, string arguments, string workingDirectory, int timeoutMs = 1500);
    }
}
