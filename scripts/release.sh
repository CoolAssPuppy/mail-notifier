#!/bin/bash
#
# One-shot release automation for Mail Notifier.
#
# Does the whole thing:
#   1. Bumps MARKETING_VERSION + CURRENT_PROJECT_VERSION in project.yml
#   2. Regenerates Xcode project with xcodegen
#   3. Archives + exports Developer ID .app
#   4. Notarizes + staples the .app
#   5. Builds DMG, notarizes + staples DMG, Sparkle-signs it
#   6. Uploads DMG + appcast.xml to Cloudflare R2 (strategic-nerds-downloads)
#   7. Verifies everything is live
#
# Prerequisites:
#   - notarytool keychain profile "agent-server" (see SPARKLE.md)
#   - Sparkle sign_update at ~/bin/sparkle/sign_update
#   - create-dmg installed (brew install create-dmg)
#   - doppler CLI logged in with access to the agent-server/prd config
#     (provides CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, R2_BUCKET_NAME, R2_PUBLIC_BASE_URL)
#   - wrangler available (npm i -g wrangler) or npx on PATH
#   - python3 on PATH
#   - xcodegen on PATH
#
# Usage:
#   ./scripts/release.sh <version> "<release notes HTML>"
#
# Example:
#   ./scripts/release.sh 3.3.0 "<li>New feature.</li><li>Bug fixes.</li>"

set -euo pipefail

VERSION="${1:?Usage: $0 <version> \"<release notes HTML>\"}"
NOTES="${2:?Usage: $0 <version> \"<release notes HTML>\"}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_ROOT/dist"
SCRIPTS="$REPO_ROOT/scripts"

NOTARY_PROFILE="${NOTARY_PROFILE:-agent-server}"
SPARKLE_SIGN_UPDATE="${SPARKLE_SIGN_UPDATE:-$HOME/bin/sparkle/sign_update}"
SIGN_IDENTITY="Developer ID Application: Prashant Sridharan (955GSY56UT)"

APP_FOLDER="mail-notifier"
DUB_SHORTLINK="https://coolasspuppy.com/mail-notifier-updates"

DOPPLER_PROJECT="${DOPPLER_PROJECT:-agent-server}"
DOPPLER_CONFIG="${DOPPLER_CONFIG:-prd}"

if command -v wrangler >/dev/null 2>&1; then
  WRANGLER=(wrangler)
else
  WRANGLER=(npx --yes wrangler)
fi

#----------------------------------------------------------------------
# Preflight
#----------------------------------------------------------------------
for tool in xcodebuild xcodegen create-dmg doppler python3 "$SPARKLE_SIGN_UPDATE"; do
  if ! command -v "$tool" >/dev/null 2>&1 && [ ! -x "$tool" ]; then
    echo "Error: required tool not found: $tool"
    exit 1
  fi
done

if ! "${WRANGLER[@]}" --version >/dev/null 2>&1; then
  echo "Error: wrangler not available. Install with: npm i -g wrangler"
  exit 1
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "Error: notarytool profile '$NOTARY_PROFILE' not found or invalid."
  echo "Run: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id ... --team-id ... --password ..."
  exit 1
fi

mkdir -p "$DIST"

#----------------------------------------------------------------------
# 1. Bump version in project.yml
#----------------------------------------------------------------------
echo "==> Bumping version to $VERSION"
CURRENT_BUILD=$(awk -F'"' '/CURRENT_PROJECT_VERSION:/ {print $2}' "$REPO_ROOT/project.yml")
NEW_BUILD=$((CURRENT_BUILD + 1))
python3 - <<PY
import re, pathlib
p = pathlib.Path("$REPO_ROOT/project.yml")
text = p.read_text()
text = re.sub(r'MARKETING_VERSION: "[^"]+"', 'MARKETING_VERSION: "$VERSION"', text)
text = re.sub(r'CURRENT_PROJECT_VERSION: "[^"]+"', 'CURRENT_PROJECT_VERSION: "$NEW_BUILD"', text)
p.write_text(text)
PY
echo "  MARKETING_VERSION=$VERSION CURRENT_PROJECT_VERSION=$NEW_BUILD"

#----------------------------------------------------------------------
# 2. Regenerate project
#----------------------------------------------------------------------
echo "==> Regenerating Xcode project"
(cd "$REPO_ROOT" && xcodegen generate)

#----------------------------------------------------------------------
# 3. Archive
#----------------------------------------------------------------------
ARCHIVE="$DIST/MailNotifier-$VERSION.xcarchive"
rm -rf "$ARCHIVE"
echo "==> Archiving"
xcodebuild -project "$REPO_ROOT/MailNotifier.xcodeproj" \
  -scheme MailNotifier \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive | xcpretty 2>/dev/null || \
xcodebuild -project "$REPO_ROOT/MailNotifier.xcodeproj" \
  -scheme MailNotifier \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive >/dev/null

#----------------------------------------------------------------------
# 4. Export Developer ID .app
#----------------------------------------------------------------------
EXPORT_DIR="$DIST/export-$VERSION"
rm -rf "$EXPORT_DIR"
echo "==> Exporting .app"
# -allowProvisioningUpdates is required when entitlements (e.g. iCloud KVS)
# need a Developer ID provisioning profile that Xcode hasn't yet downloaded.
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$SCRIPTS/export-options.plist" \
  -allowProvisioningUpdates >/dev/null

APP_PATH="$EXPORT_DIR/Mail Notifier.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Error: export did not produce $APP_PATH"
  exit 1
fi

#----------------------------------------------------------------------
# 5. Notarize + staple the .app
#----------------------------------------------------------------------
echo "==> Notarizing .app (takes a few minutes)"
APP_ZIP="$EXPORT_DIR/MailNotifier.app.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$APP_ZIP"

echo "==> Stapling .app"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

#----------------------------------------------------------------------
# 6. DMG + notarize + staple + Sparkle sign
#----------------------------------------------------------------------
echo "==> Building DMG"
"$SCRIPTS/build-dmg.sh" "$APP_PATH" "$VERSION" "$NOTARY_PROFILE"

DMG="$DIST/MailNotifier-$VERSION.dmg"
SPARKLE_TXT="$DIST/MailNotifier-$VERSION.sparkle.txt"

if [ ! -f "$DMG" ] || [ ! -f "$SPARKLE_TXT" ]; then
  echo "Error: DMG or sparkle signature missing after build-dmg.sh"
  exit 1
fi

#----------------------------------------------------------------------
# 7. Fetch Cloudflare R2 credentials from Doppler
#----------------------------------------------------------------------
echo "==> Fetching Cloudflare R2 credentials from Doppler ($DOPPLER_PROJECT/$DOPPLER_CONFIG)"
export CLOUDFLARE_API_TOKEN
CLOUDFLARE_API_TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN \
  --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain 2>/dev/null || true)
export CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_ACCOUNT_ID=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID \
  --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain 2>/dev/null || true)
R2_BUCKET=$(doppler secrets get R2_BUCKET_NAME \
  --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain 2>/dev/null || echo "strategic-nerds-downloads")
R2_PUBLIC_BASE=$(doppler secrets get R2_PUBLIC_BASE_URL \
  --project "$DOPPLER_PROJECT" --config "$DOPPLER_CONFIG" --plain 2>/dev/null || echo "https://downloads.strategicnerds.com")

if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then
  echo "Error: missing CLOUDFLARE_API_TOKEN or CLOUDFLARE_ACCOUNT_ID in Doppler $DOPPLER_PROJECT/$DOPPLER_CONFIG"
  exit 1
fi

#----------------------------------------------------------------------
# 8. Upload DMG to R2
#----------------------------------------------------------------------
DMG_NAME="MailNotifier-$VERSION.dmg"
R2_DMG_KEY="apps/$APP_FOLDER/$DMG_NAME"
echo "==> Uploading $DMG_NAME to R2 ($R2_BUCKET/$R2_DMG_KEY)"
"${WRANGLER[@]}" r2 object put "$R2_BUCKET/$R2_DMG_KEY" \
  --file="$DMG" \
  --content-type="application/x-apple-diskimage" \
  --remote

# Also upload as MailNotifier-latest.dmg so the strategic-nerds site has a stable URL
R2_LATEST_KEY="apps/$APP_FOLDER/MailNotifier-latest.dmg"
echo "==> Uploading latest.dmg alias to R2 ($R2_BUCKET/$R2_LATEST_KEY)"
"${WRANGLER[@]}" r2 object put "$R2_BUCKET/$R2_LATEST_KEY" \
  --file="$DMG" \
  --content-type="application/x-apple-diskimage" \
  --remote

#----------------------------------------------------------------------
# 9. Update appcast.xml and upload to R2
#----------------------------------------------------------------------
APPCAST="$DIST/appcast.xml"
echo "==> Prepending new <item> to appcast.xml"

ED_SIG=$(grep -oE 'sparkle:edSignature="[^"]+"' "$SPARKLE_TXT" | sed -E 's/.*"([^"]+)"/\1/')
LENGTH=$(grep -oE 'length="[^"]+"' "$SPARKLE_TXT" | sed -E 's/.*"([^"]+)"/\1/')
PUB_DATE=$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S +0000")
ENCLOSURE_URL="$R2_PUBLIC_BASE/apps/$APP_FOLDER/$DMG_NAME"

python3 - <<PY
import pathlib, re

p = pathlib.Path("$APPCAST")
xml = p.read_text()

new_item = f'''    <item>
      <title>Version $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$NEW_BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <ul>
          $NOTES
        </ul>
      ]]></description>
      <enclosure
        url="$ENCLOSURE_URL"
        sparkle:edSignature="$ED_SIG"
        length="$LENGTH"
        type="application/x-apple-diskimage" />
    </item>
'''

marker = "<language>en</language>"
if marker not in xml:
    raise SystemExit("Could not find <language>en</language> insertion point in appcast.xml")
xml = xml.replace(marker, marker + "\n" + new_item, 1)
p.write_text(xml)
PY

R2_APPCAST_KEY="apps/$APP_FOLDER/appcast.xml"
echo "==> Uploading appcast.xml to R2 ($R2_BUCKET/$R2_APPCAST_KEY)"
"${WRANGLER[@]}" r2 object put "$R2_BUCKET/$R2_APPCAST_KEY" \
  --file="$APPCAST" \
  --content-type="application/xml; charset=utf-8" \
  --remote

#----------------------------------------------------------------------
# 10. Verify
#----------------------------------------------------------------------
echo ""
echo "==> Verifying uploaded DMG"
curl -sI "$ENCLOSURE_URL" | grep -iE '^(HTTP|content-length)'
echo ""
echo "==> Verifying appcast at R2"
curl -sI "$R2_PUBLIC_BASE/$R2_APPCAST_KEY" | grep -iE '^(HTTP|content-length)'
echo ""
echo "==> Verifying appcast via Dub shortlink"
curl -sL "$DUB_SHORTLINK" | grep -E '<(title|sparkle:shortVersionString|enclosure)' | head -6

echo ""
echo "============================================================"
echo "Released Mail Notifier $VERSION (build $NEW_BUILD)"
echo ""
echo "Local artifacts:"
echo "  $DMG"
echo "  $SPARKLE_TXT"
echo "  $APPCAST"
echo ""
echo "Live:"
echo "  $ENCLOSURE_URL"
echo "  $R2_PUBLIC_BASE/$R2_APPCAST_KEY"
echo "  $DUB_SHORTLINK"
echo ""
echo "Don't forget to commit: project.yml + dist/appcast.xml"
echo "============================================================"
