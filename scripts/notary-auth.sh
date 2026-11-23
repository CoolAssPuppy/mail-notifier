#!/bin/bash
#
# Notarization credentials for release.sh and build-dmg.sh. Source it, then
# pass "${NOTARY_ARGS[@]}" to `xcrun notarytool`.
#
# Uses the App Store Connect team API key in Doppler mobile-release/prd, which
# every app's release shares. The private key is written to a temporary file
# readable only by you and removed when the shell that sourced this exits.
#
# Set NOTARY_PROFILE to use a notarytool keychain profile instead.

NOTARY_DOPPLER_PROJECT="${NOTARY_DOPPLER_PROJECT:-mobile-release}"
NOTARY_DOPPLER_CONFIG="${NOTARY_DOPPLER_CONFIG:-prd}"

notary_auth_setup() {
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
    return 0
  fi

  local key_id issuer_id
  key_id=$(doppler secrets get ASC_KEY_ID \
    --project "$NOTARY_DOPPLER_PROJECT" --config "$NOTARY_DOPPLER_CONFIG" --plain 2>/dev/null || true)
  issuer_id=$(doppler secrets get ASC_ISSUER_ID \
    --project "$NOTARY_DOPPLER_PROJECT" --config "$NOTARY_DOPPLER_CONFIG" --plain 2>/dev/null || true)
  if [ -z "$key_id" ] || [ -z "$issuer_id" ]; then
    echo "Error: ASC_KEY_ID or ASC_ISSUER_ID missing from Doppler $NOTARY_DOPPLER_PROJECT/$NOTARY_DOPPLER_CONFIG"
    return 1
  fi

  NOTARY_KEY_DIR=$(mktemp -d)
  chmod 700 "$NOTARY_KEY_DIR"
  trap 'rm -rf "$NOTARY_KEY_DIR"' EXIT
  local key_path="$NOTARY_KEY_DIR/AuthKey_$key_id.p8"
  (umask 077 && doppler secrets get ASC_PRIVATE_KEY \
    --project "$NOTARY_DOPPLER_PROJECT" --config "$NOTARY_DOPPLER_CONFIG" --plain > "$key_path") || true
  if [ ! -s "$key_path" ]; then
    echo "Error: ASC_PRIVATE_KEY missing from Doppler $NOTARY_DOPPLER_PROJECT/$NOTARY_DOPPLER_CONFIG"
    return 1
  fi

  NOTARY_ARGS=(--key "$key_path" --key-id "$key_id" --issuer "$issuer_id")
}
