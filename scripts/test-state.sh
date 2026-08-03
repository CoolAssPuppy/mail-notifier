#!/bin/bash
#
# Set up and tear down local state for the Mail Notifier Pro sandbox pass.
#
#   ./scripts/test-state.sh status          what is configured right now
#   ./scripts/test-state.sh backup          snapshot the app's UserDefaults
#   ./scripts/test-state.sh restore         put the snapshot back
#   ./scripts/test-state.sh accounts N      keep only the first N accounts
#   ./scripts/test-state.sh clear-license   forget the license and the cache
#   ./scripts/test-state.sh run             launch the Debug build
#   ./scripts/test-state.sh quit            stop it, which `xcodebuild test` needs
#
# Why this exists: the Debug build carries the same bundle id as the copy in
# /Applications, so it reads the same UserDefaults and the same Keychain. There
# is no separate sandbox profile to test against. Every command here therefore
# operates on real configuration, and every mutating one snapshots first.
#
# What it will not touch: the OAuth tokens. Removing an account through the app
# UI clears its Keychain entry and costs a re-authorization; trimming the
# accounts list here only rewrites UserDefaults, so the tokens survive and
# `restore` brings the account back intact.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="com.strategicnerds.MailNotifierApp"
STATE_DIR="$REPO_ROOT/.test-state"
SNAPSHOT="$STATE_DIR/defaults.plist"
CMD="${1:-status}"

is_running() { pgrep -qf "Mail Notifier.app/Contents/MacOS/Mail Notifier"; }

# `tell application "Mail Notifier" to quit` does not reliably stop this app, and
# a leftover process makes `xcodebuild test` fail to launch the test host. Signal
# the pids directly.
quit_app() {
  is_running || return 0
  pkill -f "Mail Notifier.app/Contents/MacOS/Mail Notifier" || true
  for _ in 1 2 3 4 5; do
    is_running || return 0
    sleep 1
  done
  pkill -9 -f "Mail Notifier.app/Contents/MacOS/Mail Notifier" || true
  sleep 1
}

require_quit() {
  if is_running; then
    echo "Error: Mail Notifier is running. Quit it first, or preferences written"
    echo "here get overwritten when it exits."
    exit 1
  fi
}

snapshot() {
  mkdir -p "$STATE_DIR"
  defaults export "$DOMAIN" "$SNAPSHOT"
}

debug_app() {
  local dir
  dir="$(xcodebuild -project "$REPO_ROOT/MailNotifier.xcodeproj" -scheme MailNotifier \
    -configuration Debug -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $2; exit}')"
  echo "$dir/Mail Notifier.app"
}

case "$CMD" in
  status)
    echo "Accounts:"
    defaults export "$DOMAIN" - 2>/dev/null | python3 -c '
import sys, json, plistlib
d = plistlib.loads(sys.stdin.buffer.read())
for i, a in enumerate(json.loads(d.get("accounts", "[]"))):
    slot = "free" if i == 0 else "needs Pro"
    state = "enabled" if a.get("enabled") else "disabled"
    print("  %d. %-38s %-8s %-9s %s" % (i + 1, a["email"], a["type"], state, slot))
' || echo "  none"

    echo "Entitlement cache:"
    if defaults read "$DOMAIN" entitlement.record.v1 >/dev/null 2>&1; then
      defaults read "$DOMAIN" entitlement.record.v1 | head -5 | sed 's/^/  /'
    else
      echo "  none (free tier)"
    fi

    echo "Keychain:"
    for acct in license.key license.activation_id; do
      if security find-generic-password -s "$DOMAIN" -a "$acct" >/dev/null 2>&1; then
        echo "  $acct present"
      else
        echo "  $acct absent"
      fi
    done

    echo "Build config:"
    app="$(debug_app)"
    if [[ -f "$app/Contents/Info.plist" ]]; then
      for k in PolarOrgID PolarBenefitID PolarCheckoutURL PolarAPIBase; do
        printf '  %-18s %s\n' "$k" \
          "$(/usr/libexec/PlistBuddy -c "Print :$k" "$app/Contents/Info.plist" 2>/dev/null || echo '(unset)')"
      done
    else
      echo "  no Debug build yet"
    fi

    if [[ -f "$SNAPSHOT" ]]; then
      echo "Snapshot: $SNAPSHOT"
    else
      echo "Snapshot: none yet, run 'backup' before you change anything"
    fi
    ;;

  backup)
    snapshot
    echo "==> Snapshotted $DOMAIN to $SNAPSHOT"
    ;;

  restore)
    require_quit
    [[ -f "$SNAPSHOT" ]] || { echo "Error: no snapshot at $SNAPSHOT"; exit 1; }
    defaults import "$DOMAIN" "$SNAPSHOT"
    killall cfprefsd 2>/dev/null || true
    echo "==> Restored $DOMAIN from the snapshot"
    ;;

  accounts)
    require_quit
    KEEP="${2:-}"
    [[ "$KEEP" =~ ^[0-9]+$ ]] || { echo "Usage: $0 accounts N"; exit 1; }
    snapshot
    defaults export "$DOMAIN" - | KEEP="$KEEP" python3 -c '
import os, sys, json, plistlib
keep = int(os.environ["KEEP"])
d = plistlib.loads(sys.stdin.buffer.read())
accounts = json.loads(d.get("accounts", "[]"))
if keep > len(accounts):
    sys.exit(f"Only {len(accounts)} accounts configured; cannot keep {keep}.")
d["accounts"] = json.dumps(accounts[:keep], separators=(",", ":"))
sys.stdout.buffer.write(plistlib.dumps(d))
' | defaults import "$DOMAIN" -
    killall cfprefsd 2>/dev/null || true
    echo "==> Kept the first $KEEP account(s). Tokens untouched; 'restore' brings the rest back."
    ;;

  clear-license)
    require_quit
    snapshot
    defaults delete "$DOMAIN" entitlement.record.v1 2>/dev/null || true
    for acct in license.key license.activation_id; do
      security delete-generic-password -s "$DOMAIN" -a "$acct" >/dev/null 2>&1 || true
    done
    killall cfprefsd 2>/dev/null || true
    echo "==> Cleared the entitlement cache and the stored license."
    echo "    Note: this forgets the key locally, it does not release the"
    echo "    activation at Polar. Use Settings, Remove license, for that, or"
    echo "    release the device from the customer portal."
    ;;

  run)
    app="$(debug_app)"
    [[ -d "$app" ]] || { echo "Error: no Debug build at $app"; exit 1; }
    if is_running; then
      echo "Quitting the running copy first."
      quit_app
    fi
    open "$app"
    echo "==> Launched $app"
    ;;

  quit)
    quit_app
    echo "==> Mail Notifier is not running."
    ;;

  *)
    sed -n '3,13p' "${BASH_SOURCE[0]}" | sed 's|^# \{0,1\}||'
    exit 1
    ;;
esac
