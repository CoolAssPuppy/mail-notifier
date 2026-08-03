#!/bin/bash
#
# Pull ONLY the POLAR_* values from Doppler into Secrets.xcconfig.
#
# Usage:
#   ./scripts/pull-polar-secrets.sh [config]    # config defaults to "dev"
#
# It rewrites the POLAR_* lines and the SLASH line, and leaves every other line
# in Secrets.xcconfig exactly as it found it. Google, Outlook, and PostHog are
# never read or written.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${DOPPLER_PROJECT:-mail-notifier}"
CONFIG="${1:-dev}"
OUT="$REPO_ROOT/Secrets.xcconfig"

KEYS=(POLAR_ORG_ID POLAR_BENEFIT_ID POLAR_CHECKOUT_URL POLAR_PORTAL_URL POLAR_API_BASE)

if ! command -v doppler >/dev/null 2>&1; then
  echo "Error: doppler CLI not found."
  exit 1
fi

[[ -f "$OUT" ]] || touch "$OUT"
cp "$OUT" "$OUT.bak"

# Keep every line that isn't ours.
grep -vE '^(SLASH|POLAR_[A-Z_]+) *=' "$OUT.bak" > "$OUT" || true

{
  echo ""
  echo "// Polar, pulled from Doppler $PROJECT/$CONFIG by scripts/pull-polar-secrets.sh"
  # xcconfig treats // as a comment and would truncate every URL, so the double
  # slash is written as $(SLASH)$(SLASH) and expands back at build time.
  echo "SLASH = /"
  for key in "${KEYS[@]}"; do
    value="$(doppler secrets get "$key" --project "$PROJECT" --config "$CONFIG" --plain 2>/dev/null || true)"
    value="$(printf '%s' "$value" | sed 's#//#$(SLASH)$(SLASH)#g')"
    echo "$key = $value"
  done
} >> "$OUT"

echo "==> Updated the POLAR_* lines in Secrets.xcconfig (backup at Secrets.xcconfig.bak)"
grep -E '^POLAR_' "$OUT"
