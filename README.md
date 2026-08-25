<div align="center">

<a href="https://luizhcrs.github.io/nuno">
  <img src="assets/banner.svg" alt="PowerAI Banner" width="100%">
</a>

<br/><br/>

[Landing Page & Web Simulator](https://luizhcrs.github.io/nuno) • [Quick Install](#quick-install) • [Commands](#commands) • [How It Works](#how-it-works) • [License](#license--terms)

---

</div>

## Quick Install

### macOS & Linux (Bash / Zsh)
```bash
curl -fsSL https://raw.githubusercontent.com/Luizhcrs/nuno/main/install.sh | bash
```

### Windows (PowerShell 5.1 / 7+)
```powershell
irm https://raw.githubusercontent.com/Luizhcrs/nuno/main/install.ps1 | iex
```

The installer is self-healing: missing dependencies (`curl`, `python3`, `jq`) and the recommended local Ollama model (`qwen2.5-coder:1.5b`) are configured automatically.

---

## Core Capabilities

- **Local-First & Offline**: Runs entirely on your machine via Ollama or local APIs with GPU acceleration.
- **Terminal Output Buffer**: Answers questions directly about command outputs printed on your screen.
- **Non-Destructive Execution**: Asks for confirmation before executing any suggested command.
- **Multi-Language Support**: Automatically detects and switches between English, Portuguese, and Spanish.
- **Auto-Healing**: Intercepts shell typos and syntax errors, proposing immediate fixes.

---

## Commands

| Command | Description |
| :--- | :--- |
| `ai <query>` | Natural language terminal query |
| `? <query>` | Fast shorthand alias |
| `ai language <pt\|en\|es>` | Change assistant language |
| `ai config` | Display current configuration |
| `ai uninstall` | Completely uninstall PowerAI |

<details>
<summary><b>Usage Examples</b></summary>

```bash
# Network & Processes
? list all open TCP ports listening for connections
? kill all hung node processes

# Files & Logs
? find all .log files larger than 100mb
? search for ERROR in the last 500 lines of app.log

# Git Operations
? undo last commit while keeping local changes
? clean local branches that were deleted on remote
```

</details>

---

## How It Works

1. **Input Capture**: You type `ai <query>` or `? <query>` in your shell.
2. **Context Resolution**: Reads minimal local context (operating system, working directory, and the last printed command output).
3. **Local Inference**: Queries are processed locally via Ollama or local OpenAI-compatible endpoints with zero external telemetry.
4. **Interactive Prompt**: Displays the proposed command with an explanation, awaiting confirmation (`Enter` to run, `Esc` to cancel).

---

<details>
<summary><b>Configuration Reference (~/.powerai/config.json)</b></summary>

```json
{
  "Mode": "Auto",
  "LocalType": "Ollama",
  "LocalEndpoint": "http://127.0.0.1:5151/v1",
  "LocalApiKey": "",
  "LocalModel": "qwen2.5-coder:1.5b",
  "OllamaEndpoint": "http://localhost:11434",
  "CloudEndpoint": "https://api.openai.com/v1",
  "CloudApiKey": "",
  "CloudModel": "gpt-4o-mini",
  "Language": "pt-BR",
  "AutoSuggestOnErrors": true,
  "AutoHealingRetries": 2,
  "TimeoutSeconds": 25
}
```

</details>

---

<details>
<summary><b>Automated Tests</b></summary>

- Unit tests (.NET / xUnit): `tests/PowerAI.Tests/`
- Integration tests (Terminal harness): `tests/test_harness.sh`

Run locally:
```bash
./tests/test_harness.sh
```

</details>

---

## License & Terms

PowerAI is distributed under the **PolyForm Noncommercial License 1.0.0**.

- **Permitted**: Free personal use on local machines, academic research, education, code review, and non-commercial community contributions.
- **Prohibited**: Commercial use, paid distribution, SaaS re-hosting, or monetization without prior written license from the copyright holder.

**Author**: Luiz Henrique ([@Luizhcrs](https://github.com/Luizhcrs))  
**Repository**: [github.com/Luizhcrs/nuno](https://github.com/Luizhcrs/nuno)
