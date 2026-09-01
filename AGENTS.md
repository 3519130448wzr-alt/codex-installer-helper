# Codex Installer Helper contributor rules

- This repository builds an independent, unofficial helper around OpenAI's documented Codex installer.
- Start downloads at `https://chatgpt.com/codex/install.sh` on macOS or `https://chatgpt.com/codex/install.ps1` on Windows; allow only the matching exact redirect at `https://releases.openai.com/codex/install.sh` or `https://releases.openai.com/codex/install.ps1`. Keep final-URL and script-content checks fail-closed.
- Never add third-party API providers, mirrors, API-key entry fields, credential-file reads, telemetry, or bundled Codex binaries.
- Do not silently remove or replace Homebrew, npm, Bun, or unknown Codex installations.
- Authentication must be delegated to `codex login`; never inspect Codex credential storage.
- Tests must use a temporary HOME and fake installer scripts. Never install, update, remove, or log in the developer machine's real Codex during automated tests.
- Run `make test`, `make security-check`, and `make app` before release work.
- Public macOS artifacts require Developer ID signing, notarization, stapling, Gatekeeper assessment, and a SHA-256 checksum. Public Windows artifacts require Authenticode signing, timestamping, signature verification, SmartScreen testing, and a SHA-256 checksum.
