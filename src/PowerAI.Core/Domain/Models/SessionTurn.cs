using System;

namespace PowerAI.Core.Domain.Models
{
    public class SessionTurn
    {
        public int TurnNumber { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
        public string Query { get; set; } = string.Empty;
        public string? SuggestedCommand { get; set; }
        public string? Explanation { get; set; }
        public string? TerminalOutput { get; set; }
    }
}
