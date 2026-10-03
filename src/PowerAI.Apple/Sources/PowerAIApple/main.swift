import Foundation

@main
struct PowerAIAppleMain {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        guard let command = args.first else {
            printHelp()
            exit(1)
        }

        let service = AppleIntelligenceService.shared
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            switch command {
            case "check":
                let result = service.checkAvailability()
                let data = try encoder.encode(result)
                if let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
                exit(result.available ? 0 : 1)

            case "version", "--version", "-v":
                print("PowerAI Apple Module v1.3.0 (FoundationModels Native)")
                exit(0)

            case "help", "--help", "-h":
                printHelp()
                exit(0)

            case "query":
                var prompt: String?
                var context: String?
                var langStr: String?

                var i = 1
                while i < args.count {
                    switch args[i] {
                    case "--prompt", "-p":
                        if i + 1 < args.count { prompt = args[i + 1]; i += 1 }
                    case "--context", "-c":
                        if i + 1 < args.count { context = args[i + 1]; i += 1 }
                    case "--lang", "-l":
                        if i + 1 < args.count { langStr = args[i + 1]; i += 1 }
                    default:
                        if prompt == nil { prompt = args[i] }
                    }
                    i += 1
                }

                guard let finalPrompt = prompt, !finalPrompt.isEmpty else {
                    throw ServiceError.invalidArguments("Missing required --prompt argument.")
                }

                let language = Language.from(raw: langStr)
                let suggestion = try await service.generateSuggestion(
                    prompt: finalPrompt,
                    context: context,
                    language: language
                )
                let data = try encoder.encode(suggestion)
                if let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
                exit(0)

            case "commit":
                var diff: String?
                var branch: String?
                var status: String?
                var langStr: String?

                var i = 1
                while i < args.count {
                    switch args[i] {
                    case "--diff", "-d":
                        if i + 1 < args.count { diff = args[i + 1]; i += 1 }
                    case "--branch", "-b":
                        if i + 1 < args.count { branch = args[i + 1]; i += 1 }
                    case "--status", "-s":
                        if i + 1 < args.count { status = args[i + 1]; i += 1 }
                    case "--lang", "-l":
                        if i + 1 < args.count { langStr = args[i + 1]; i += 1 }
                    default:
                        if diff == nil { diff = args[i] }
                    }
                    i += 1
                }

                guard let finalDiff = diff, !finalDiff.isEmpty else {
                    throw ServiceError.invalidArguments("Missing required --diff argument.")
                }

                let language = Language.from(raw: langStr)
                let suggestion = try await service.generateCommit(
                    diff: finalDiff,
                    branch: branch,
                    status: status,
                    language: language
                )
                let data = try encoder.encode(suggestion)
                if let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
                exit(0)

            case "explain":
                var targetCmd: String?
                var langStr: String?

                var i = 1
                while i < args.count {
                    switch args[i] {
                    case "--cmd":
                        if i + 1 < args.count { targetCmd = args[i + 1]; i += 1 }
                    case "--lang", "-l":
                        if i + 1 < args.count { langStr = args[i + 1]; i += 1 }
                    default:
                        if targetCmd == nil {
                            targetCmd = args[i...].joined(separator: " ")
                            i = args.count
                        }
                    }
                    i += 1
                }

                guard let finalCmd = targetCmd, !finalCmd.isEmpty else {
                    throw ServiceError.invalidArguments("Missing required --cmd argument.")
                }

                let language = Language.from(raw: langStr)
                let explanation = try await service.explainCommand(
                    command: finalCmd,
                    language: language
                )
                let result = CommandSuggestion(
                    suggested_command: "",
                    explanation: explanation.explanation
                )
                let data = try encoder.encode(result)
                if let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
                exit(0)

            default:
                throw ServiceError.invalidArguments("Unknown command: \(command)")
            }
        } catch {
            let errResult = ErrorResult(error: error.localizedDescription, code: 1)
            if let data = try? encoder.encode(errResult), let str = String(data: data, encoding: .utf8) {
                FileHandle.standardError.write(Data(str.utf8))
                FileHandle.standardError.write(Data("\n".utf8))
            } else {
                FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            }
            exit(1)
        }
    }

    static func printHelp() {
        print("""
        PowerAI Apple Intelligence Native Module
        Usage: powerai-apple <command> [options]

        Commands:
          check                           Verify if Apple Intelligence is available
          query --prompt <text>           Generate command suggestion for terminal
                [--context <text>]        Environment and terminal history context
                [--lang <pt|en|es>]       Output language (default: pt-BR)
          commit --diff <diff>            Generate Conventional Commit message
                 [--branch <name>]        Git branch
                 [--status <status>]      Git status output
                 [--lang <pt|en|es>]      Output language
          explain --cmd <command>         Breakdown and explain a shell command
                  [--lang <pt|en|es>]     Output language
          version                         Print module version
          help                            Show this help message
        """)
    }
}
