namespace PowerAI.Core.Domain.Models
{
    public class SuggestionResult
    {
        public bool Success { get; set; }
        public string? SuggestedCommand { get; set; }
        public string? Explanation { get; set; }
        public string? RawResponse { get; set; }
        public string? ProviderUsed { get; set; }
    }
}
