import Foundation
import FoundationModels

@Generable
public struct CommandSuggestion: Codable, Sendable {
    @Guide(description: "The complete, executable shell command for macOS terminal (e.g. 'git commit -m \"feat: add Apple Intelligence support\"', 'ls -la'), or empty string if purely informational.")
    public var suggested_command: String

    @Guide(description: "Concise explanation of the command or direct answer in the requested language.")
    public var explanation: String

    public init(suggested_command: String, explanation: String) {
        self.suggested_command = suggested_command
        self.explanation = explanation
    }
}

@Generable
public struct ExplainSuggestion: Codable, Sendable {
    @Guide(description: "Detailed, structured breakdown of the command and its arguments/flags.")
    public var explanation: String

    public init(explanation: String) {
        self.explanation = explanation
    }
}

public struct CheckResult: Codable, Sendable {
    public let available: Bool
    public let model: String
    public let provider: String
    public let os: String
    public let details: String?

    public init(available: Bool, model: String = "SystemLanguageModel", provider: String = "AppleIntelligence", os: String = "macOS", details: String? = nil) {
        self.available = available
        self.model = model
        self.provider = provider
        self.os = os
        self.details = details
    }
}

public struct ErrorResult: Codable, Sendable {
    public let error: String
    public let code: Int

    public init(error: String, code: Int = 1) {
        self.error = error
        self.code = code
    }
}
