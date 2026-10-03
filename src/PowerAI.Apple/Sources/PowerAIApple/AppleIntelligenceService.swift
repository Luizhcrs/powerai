import Foundation
import FoundationModels

public final class AppleIntelligenceService: Sendable {
    public static let shared = AppleIntelligenceService()

    private init() {}

    public func checkAvailability() -> CheckResult {
        let isAvail = SystemLanguageModel.default.isAvailable
        let availDesc = String(describing: SystemLanguageModel.default.availability)
        return CheckResult(
            available: isAvail,
            model: "SystemLanguageModel",
            provider: "AppleIntelligence",
            os: "macOS",
            details: availDesc
        )
    }

    public func generateSuggestion(
        prompt: String,
        context: String?,
        language: Language
    ) async throws -> CommandSuggestion {
        guard SystemLanguageModel.default.isAvailable else {
            throw ServiceError.modelUnavailable("SystemLanguageModel is not available on this device.")
        }

        let instructions = Prompts.systemInstructions(language: language, context: context)
        let session = LanguageModelSession(instructions: instructions)

        do {
            let response = try await session.respond(
                to: prompt,
                generating: CommandSuggestion.self
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            throw ServiceError.generationFailed("Apple Intelligence Generation Error: \(error.localizedDescription)")
        }
    }

    public func generateCommit(
        diff: String,
        branch: String?,
        status: String?,
        language: Language
    ) async throws -> CommandSuggestion {
        guard SystemLanguageModel.default.isAvailable else {
            throw ServiceError.modelUnavailable("SystemLanguageModel is not available on this device.")
        }

        let instructions = Prompts.commitInstructions(language: language, branch: branch, status: status)
        let session = LanguageModelSession(instructions: instructions)

        let prompt = """
        Gere o comando de commit ideal no padrão Conventional Commits para as seguintes alterações:
        \(diff)
        """

        let response = try await session.respond(
            to: prompt,
            generating: CommandSuggestion.self
        )
        return response.content
    }

    public func explainCommand(
        command: String,
        language: Language
    ) async throws -> ExplainSuggestion {
        guard SystemLanguageModel.default.isAvailable else {
            throw ServiceError.modelUnavailable("SystemLanguageModel is not available on this device.")
        }

        let instructions = Prompts.explainInstructions(language: language)
        let session = LanguageModelSession(instructions: instructions)

        let prompt = "Explique este comando e suas flags em detalhes: \(command)"
        let response = try await session.respond(
            to: prompt,
            generating: ExplainSuggestion.self
        )
        return response.content
    }
}

public enum ServiceError: LocalizedError, Sendable {
    case modelUnavailable(String)
    case generationFailed(String)
    case invalidArguments(String)

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable(let msg): return msg
        case .generationFailed(let msg): return msg
        case .invalidArguments(let msg): return msg
        }
    }
}
