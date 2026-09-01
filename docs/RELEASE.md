# Release runbook

Public release is intentionally separate from local development. An ad-hoc signed DMG must never be uploaded as a public release.

## Required credentials

- Apple Developer Program membership
- Developer ID Application certificate and private key
- App Store Connect API key with notary access, or a `notarytool` keychain profile
- A dedicated public repository for this installer helper

Do not copy credentials into the repository. CI expects encrypted secrets:

- `MACOS_CERTIFICATE_P12_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `APPLE_DEVELOPER_ID_NAME`
- `APPLE_TEAM_ID`
- `APPLE_API_PRIVATE_KEY_BASE64`
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`

## Local release

Run all checks:

```bash
make test
make security-check
```

Build and sign:

```bash
SIGNING_IDENTITY="Developer ID Application: NAME (TEAMID)" \
VERSION="0.1.0" \
BUILD_NUMBER="1" \
make dmg
```

Submit using a saved keychain profile:

```bash
NOTARY_PROFILE="codex-installer-notary" \
VERSION="0.1.0" \
bash scripts/notarize.sh
```

The notarization script staples the ticket, validates it, runs Gatekeeper assessment, and regenerates the checksum after stapling.

## Manual acceptance

Test the final downloaded DMG rather than the build-directory copy:

1. Verify the published SHA-256 checksum.
2. Run `hdiutil verify`.
3. Open the DMG and drag the app to Applications.
4. Confirm Gatekeeper opens it without an unidentified-developer warning.
5. Test a clean install on Apple Silicon and Intel macOS 13 or newer.
6. Verify re-running updates the standalone installation.
7. Verify an existing Homebrew/npm/Bun installation is not changed.
8. Cancel browser OAuth and verify device-auth fallback remains available.
9. Finish OAuth and confirm the completion screen appears only after `codex login status` succeeds.
10. Inspect the app bundle for bundled Codex binaries, credentials, provider configuration, or telemetry.

## Versioning

The helper follows semantic versioning independently of the Codex version it installs. Start with `v0.1.0-beta.1`; publish `v1.0.0` only after the clean-machine matrix passes.

## Windows signing and release

The Windows workflow builds separate self-contained x64 and ARM64 executables. Configure these encrypted repository secrets:

- `WINDOWS_CERTIFICATE_PFX_BASE64`
- `WINDOWS_CERTIFICATE_PASSWORD`
- `WINDOWS_TIMESTAMP_URL` (an RFC 3161 timestamp service allowed by the certificate issuer)

On a Windows development machine, run:

```powershell
windows\scripts\test.ps1
windows\scripts\security-check.ps1
windows\scripts\build.ps1 -Runtime win-x64 -Version 0.1.0
windows\scripts\build.ps1 -Runtime win-arm64 -Version 0.1.0
```

The tag-triggered workflow fails closed if signing material is missing. It signs and timestamps both `.exe` files, verifies them with `signtool` and `Get-AuthenticodeSignature`, then generates SHA-256 files. Certificates and passwords must never be committed.

Before a Windows public release, download both artifacts from GitHub and complete the x64/ARM64 and SmartScreen matrix in [WINDOWS_PHASE_2.md](WINDOWS_PHASE_2.md).
