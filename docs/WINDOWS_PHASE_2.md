# Windows implementation and acceptance

Windows MVP source and release automation are implemented under `windows/`. Public availability remains gated on signed clean-machine acceptance; an untested local build must not be presented as a finished public installer.

## Fixed architecture

- C# and .NET 8 desktop application, published as a self-contained single-file `win-x64` and `win-arm64` executable.
- Download only `https://chatgpt.com/codex/install.ps1` with redirects restricted to the exact official HTTPS endpoint.
- Validate HTTP success, a bounded script size, the PowerShell parameter block, `CODEX_INSTALL_DIR`, and `releases.openai.com/codex` before execution.
- Run PowerShell with `CODEX_NON_INTERACTIVE=true`, then verify the expected `%LOCALAPPDATA%\Programs\OpenAI\Codex\bin\codex.exe` directly.
- Delegate login to `codex.exe login` and verify with `codex.exe login status`; never inspect auth storage.
- Detect existing npm/Bun/unknown installations and avoid silent replacement or uninstall.

## Release gates

- Build and unit-test both architectures on Windows runners.
- Sign the executable with an organization-validation or extended-validation code-signing certificate and timestamp it.
- Verify Authenticode signatures with `Get-AuthenticodeSignature` and `signtool verify /pa`.
- Test SmartScreen on a clean Windows 11 x64 device and an ARM64 device before public release.
- Publish separate architecture-labelled files and SHA-256 checksums.

## Implemented

- Code-only WinForms interface with environment inspection, explicit install confirmation, progress, diagnostics, login fallback, version and path results.
- Fail-closed downloader with exact HTTPS endpoint allowlist, size bound and official script-content signals.
- User-level PowerShell execution with `CODEX_NON_INTERACTIVE=true`, direct standalone path verification, and no admin manifest.
- npm/Bun/unknown-path detection that reuses the existing command without uninstalling or adding a standalone copy.
- Custom no-NuGet console test runner, temporary-profile fake installer integration test, and source security scan.
- GitHub Actions builds x64 and ARM64 self-contained single-file executables, requires Authenticode signing and RFC 3161 timestamping, verifies signatures, and publishes SHA-256 files.

## Still requires Windows hardware

1. Run `windows\scripts\test.ps1` and `windows\scripts\security-check.ps1` on Windows 11.
2. Test clean install, standalone update, npm conflict, Bun conflict, no-admin account, browser-login cancellation and device-auth fallback on x64.
3. Repeat clean install, update and login on Windows 11 ARM64.
4. Download the signed release artifacts from GitHub rather than using CI workspace copies.
5. Confirm SmartScreen and Authenticode behavior, then publish the beta to the external test group.
