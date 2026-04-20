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
#   6. Uploads DMG + appcast.xml to Supabase Storage
#   7. Verifies everything is live
#
# Prerequisites:
#   - notarytool keychain profile "mail-notifier" (see SPARKLE.md)
#   - Sparkle sign_update at ~/bin/sparkle/sign_update
#   - create-dmg installed (brew install create-dmg)
#   - doppler CLI logged in with access to the agent-server/prd config
#     (we reuse that Supabase service-role key since the bucket is shared)
#   - python3 on PATH
#   - xcodegen on PATH
#
# Usage:
#   ./scripts/release.sh <version> "<release notes HTML>"
#
# Example:
#   ./scripts/release.sh 3.1.0 "<li>First Developer ID release.</li><li>Auto-updates via Sparkle.</li>"

set -euo pipefail

VERSION="${1:?Usage: $0 <version> \"<release notes HTML>\"}"
NOTES="${2:?Usage: $0 <version> \"<release notes HTML>\"}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_ROOT/dist"
SCRIPTS="$REPO_ROOT/scripts"

NOTARY_PROFILE="${NOTARY_PROFILE:-agent-server}"
SPARKLE_SIGN_UPDATE="${SPARKLE_SIGN_UPDATE:-$HOME/bin/sparkle/sign_update}"
SIGN_IDENTITY="Developer ID Application: Prashant Sridharan (955GSY56UT)"

SUPABASE_URL="https://hlwjnusdotqtmtwrjidu.supabase.co"
SUPABASE_BUCKET="downloads"
DUB_SHORTLINK="https://coolasspuppy.com/mail-notifier-updates"
APPCAST_REMOTE_NAME="mail-notifier-appcast.xml"

DOPPLER_PROJECT="${DOPPLER_PROJECT:-agent-server}"
DOPPLER_CONFIG="${DOPPLER_CONFIG:-prd}"
DOPPLER_KEY_NAME="${DOPPLER_KEY_NAME:-SB_AGENT_PANEL_SERVICE_ROLE_KEY}"

#----------------------------------------------------------------------
# Preflight
#----------------------------------------------------------------------
for tool in xcodebuild xcodegen create-dmg doppler python3 "$SPARKLE_SIGN_UPDATE"; do
  if ! command -v "$tool" >/dev/null 2>&1 && [ ! -x "$tool" ]; then
    echo "Error: required tool not found: $tool"
    exit 1
  fi
done

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
  archive | xcpretty 2>/dev/null || \
xcodebuild -project "$REPO_ROOT/MailNotifier.xcodeproj" \
  -scheme MailNotifier \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  archive >/dev/null

#----------------------------------------------------------------------
# 4. Export Developer ID .app
#----------------------------------------------------------------------
EXPORT_DIR="$DIST/export-$VERSION"
rm -rf "$EXPORT_DIR"
echo "==> Exporting .app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$SCRIPTS/export-options.plist" >/dev/null

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
# 7. Fetch Supabase service role key via Doppler
#----------------------------------------------------------------------
echo "==> Fetching Supabase service role key from Doppler"
SB_KEY=$(doppler secrets get "$DOPPLER_KEY_NAME" \
  --project "$DOPPLER_PROJECT" \
  --config "$DOPPLER_CONFIG" \
  --plain 2>/dev/null || true)
if [ -z "$SB_KEY" ]; then
  echo "Error: could not fetch $DOPPLER_KEY_NAME from Doppler."
  echo "Run 'doppler login' and confirm access to $DOPPLER_PROJECT/$DOPPLER_CONFIG."
  exit 1
fi

#----------------------------------------------------------------------
# 8. Upload DMG
#----------------------------------------------------------------------
DMG_NAME="MailNotifier-$VERSION.dmg"
echo "==> Uploading $DMG_NAME to Supabase bucket '$SUPABASE_BUCKET'"
HTTP_CODE=$(curl -sS -o /tmp/mailnotifier-upload.out -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $SB_KEY" \
  -H "apikey: $SB_KEY" \
  -H "Content-Type: application/x-apple-diskimage" \
  -H "x-upsert: true" \
  --data-binary "@$DMG" \
  "$SUPABASE_URL/storage/v1/object/$SUPABASE_BUCKET/$DMG_NAME")
if [ "$HTTP_CODE" != "200" ]; then
  echo "Error: DMG upload failed (HTTP $HTTP_CODE)"
  cat /tmp/mailnotifier-upload.out
  exit 1
fi

#----------------------------------------------------------------------
# 9. Update appcast.xml and upload
#----------------------------------------------------------------------
APPCAST="$DIST/appcast.xml"
echo "==> Prepending new <item> to appcast.xml"

ED_SIG=$(grep -oE 'sparkle:edSignature="[^"]+"' "$SPARKLE_TXT" | sed -E 's/.*"([^"]+)"/\1/')
LENGTH=$(grep -oE 'length="[^"]+"' "$SPARKLE_TXT" | sed -E 's/.*"([^"]+)"/\1/')
PUB_DATE=$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S +0000")
ENCLOSURE_URL="$SUPABASE_URL/storage/v1/object/public/$SUPABASE_BUCKET/$DMG_NAME"

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

echo "==> Uploading $APPCAST_REMOTE_NAME"
HTTP_CODE=$(curl -sS -o /tmp/mailnotifier-upload.out -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $SB_KEY" \
  -H "apikey: $SB_KEY" \
  -H "Content-Type: application/xml" \
  -H "x-upsert: true" \
  --data-binary "@$APPCAST" \
  "$SUPABASE_URL/storage/v1/object/$SUPABASE_BUCKET/$APPCAST_REMOTE_NAME")
if [ "$HTTP_CODE" != "200" ]; then
  echo "Error: appcast upload failed (HTTP $HTTP_CODE)"
  cat /tmp/mailnotifier-upload.out
  exit 1
fi

#----------------------------------------------------------------------
# 10. Verify
#----------------------------------------------------------------------
echo ""
echo "==> Verifying uploaded DMG"
curl -sI "$SUPABASE_URL/storage/v1/object/public/$SUPABASE_BUCKET/$DMG_NAME" \
  | grep -iE '^(HTTP|content-length)'
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
echo "  $DUB_SHORTLINK"
echo ""
echo "Don't forget to commit: project.yml + dist/appcast.xml"
echo "============================================================"
