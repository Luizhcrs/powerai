# Contributing to PowerAI

Thank you for your interest in contributing to PowerAI! We welcome bug reports, feature suggestions, documentation improvements, and pull requests.

---

## Code of Conduct

This project and everyone participating in it is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

## How Can I Contribute?

### 1. Reporting Bugs
- Check existing [Issues](https://github.com/Luizhcrs/powerai/issues) before opening a new one to avoid duplicates.
- Use the **Bug Report** template.
- Include your operating system (macOS, Linux distro, Windows), shell version (`bash --version`, `zsh --version`, or `$PSVersionTable`), and Ollama model in use.

### 2. Suggesting Enhancements
- Open a feature request using the **Feature Request** template.
- Clearly describe the use case, expected terminal workflow, and why this improvement benefits other users.

### 3. Submitting Pull Requests
1. Fork the repository and create your branch from `dev`:
   ```bash
   git checkout -b feature/my-new-feature origin/dev
   ```
2. Keep your changes focused and concise.
3. Verify all automated tests pass:
   ```bash
   ./tests/test_harness.sh
   ```
4. Commit your changes using conventional commit format:
   ```bash
   git commit -m "feat(module): add new capability"
   ```
5. Push to your fork and submit a Pull Request targeting the **`dev`** branch.

---

## Development & Architecture Guidelines

- **Zero Heavy Dependencies**: Keep the Unix harness (`powerai.sh`) lightweight, fast, and reliant only on standard shell utilities and `jq`.
- **Zero Risk**: Never execute shell commands automatically without explicit user confirmation.
- **Privacy First**: Do not introduce remote telemetry, data collection, or network egress outside the user-configured LLM endpoint.

---

## Questions?

Feel free to open a [Discussion](https://github.com/Luizhcrs/powerai/issues) or reach out to the project maintainers.
