# Security policy

## Design commitments

- Fail closed unless the installer stays on the exact documented `chatgpt.com` endpoint or its matching exact `releases.openai.com` redirect, and reject unexpected HTTP status, script size, platform script markers, install-directory marker, or official release-host signal.
- Delegate release archive selection and SHA-256 verification to OpenAI's official installer.
- Never bundle Codex, credentials, provider configuration, or third-party endpoints.
- Never silently uninstall or replace a package-manager-owned Codex.
- Keep downloaded scripts in a unique per-user temporary directory (`0700` on macOS) and remove that directory after execution.
- Verify the resulting executable directly with `codex --version` before authentication.
- Treat authentication as an opaque Codex subprocess; never inspect credential storage.

## Reporting a vulnerability

Do not include passwords, tokens, API keys, browser data, or private project files in a report. Provide the installer-helper version, operating-system version, CPU architecture, reproducible steps, and redacted local diagnostics.

## Release requirements

Every public build must pass its platform core tests and security check and ship with a SHA-256 checksum. macOS artifacts must be Developer ID signed with Hardened Runtime and timestamping, notarized, stapled, and Gatekeeper-assessed. Windows artifacts must be Authenticode signed and timestamped, pass `signtool` and `Get-AuthenticodeSignature` verification, and complete clean-device SmartScreen acceptance on x64 and ARM64.
