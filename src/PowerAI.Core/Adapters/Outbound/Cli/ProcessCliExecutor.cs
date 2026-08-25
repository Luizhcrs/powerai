using System.Diagnostics;
using PowerAI.Core.Ports.Outbound;

namespace PowerAI.Core.Adapters.Outbound.Cli
{
    public class ProcessCliExecutor : ICliExecutor
    {
        public string? ExecuteCommand(string executable, string arguments, string workingDirectory, int timeoutMs = 1500)
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = executable,
                    Arguments = arguments,
                    WorkingDirectory = workingDirectory,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var proc = Process.Start(psi);
                if (proc == null) return null;
                string output = proc.StandardOutput.ReadToEnd();
                proc.WaitForExit(timeoutMs);
                return output;
            }
            catch
            {
                return null;
            }
        }
    }
}
