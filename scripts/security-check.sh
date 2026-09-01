#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if rg -n -i \
    'aitianhu|ANTHROPIC_(AUTH_TOKEN|BASE_URL)|OPENAI_API_KEY|base_url[[:space:]]*=|sentry|mixpanel|amplitude|segment\.io' \
    "$PROJECT_DIR/Sources" "$PROJECT_DIR/Resources"; then
    echo "Security check failed: forbidden provider, credential, or telemetry pattern found." >&2
    exit 1
fi

if find "$PROJECT_DIR" -type f \( -name 'auth.json' -o -name 'codex' -o -name 'codex.exe' \) \
    -not -path "$PROJECT_DIR/.build/*" \
    -not -path "$PROJECT_DIR/build/*" | grep -q .; then
    echo "Security check failed: bundled Codex binary or credential file found." >&2
    exit 1
fi

if rg -n 'package\(url:|\.package\(url:' "$PROJECT_DIR/Package.swift"; then
    echo "Security check failed: unexpected external Swift package dependency." >&2
    exit 1
fi

echo "Security check passed."
