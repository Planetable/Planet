#!/bin/bash
#
# Build and publish a Planet insider release from this Mac.
# Replaces .github/workflows/insider.yml (disabled on 2026-11-24).
#
#   tools/release-insider.sh build [tag]   Local only: tag main, archive, sign, notarize, zip, make the appcast.
#   tools/release-insider.sh push-tag <tag>
#   tools/release-insider.sh github <tag>  GitHub prerelease with the app and dSYM zips.
#   tools/release-insider.sh spaces <tag>  Upload the zip and appcast.xml to DigitalOcean Spaces, purge the appcast from the CDN.
#   tools/release-insider.sh verify <tag>  Check the live appcast and download.
#
# Everything after `build` publishes something; run those only after the build has been checked.
#
# Needs on this Mac:
#   - Developer ID Application certificate and the "Developer ID Profile" provisioning profile
#   - notarytool keychain profile "planet-notary"
#   - Sparkle EdDSA private key in the login keychain (generate_keys -f)
#   - Planet/local.xcconfig with WALLETCONNECTV2_PROJECT_ID and ETHERSCAN_API_TOKEN
#   - keychain items planet-release.digitalocean-api (account planetable) and
#     planet-release.spaces.planetable (accounts access_key and secret_key)
#   - gh, git-lfs, rclone, xmlstarlet

set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORKSPACE=${PLANET_RELEASE_DIR:-$HOME/Developer/planet-releases}
SRC=$WORKSPACE/src
DERIVED_DATA=$WORKSPACE/DerivedData

if [ -d /Applications/Xcode.app/Contents/Developer ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
else
  export DEVELOPER_DIR=/Applications/Xcode-16.4.0.app/Contents/Developer
fi

SIGN_IDENTITY="Developer ID Application: Xin Liu (66KP7KX9MX)"
NOTARY_PROFILE=planet-notary
FEED_URL=https://opensource.planetable.xyz/planet-insider/appcast.xml
DOWNLOAD_BASE=https://opensource.planetable.xyz/planet-insider
WEBSITE_LINK=https://planetable.eth.limo/insider/
RELEASE_NOTES_URL=https://insider.planetable.xyz/
SPACE=planetable
SPACE_ENDPOINT=sfo3.digitaloceanspaces.com
CDN_ENDPOINT_ID=fc623564-5ed6-4a82-844c-d4faf3bde159
APP_NAME=Planet-Insider

step() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

xcconfig_value() {
  sed -nE "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\"?([^\";]*)\"?;?[[:space:]]*$/\1/p" "$1" | tail -1
}

sparkle_bin() {
  local bin=$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin
  [ -x "$bin/generate_appcast" ] || die "Sparkle tools not found in $bin; run build first"
  echo "$bin"
}

next_tag() {
  local today n=1
  today=$(date +%Y%m%d)
  git -C "$REPO" fetch -q --tags origin
  while git -C "$REPO" rev-parse -q --verify "refs/tags/insider-$today-$n" >/dev/null; do
    n=$((n + 1))
  done
  echo "insider-$today-$n"
}

out_dir() { echo "$WORKSPACE/$1"; }

plist() { /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null || true; }

build() {
  local tag=${1:-}

  step "Checking the repository"
  [ -z "$(git -C "$REPO" status --porcelain)" ] || die "working tree is not clean"
  [ "$(git -C "$REPO" branch --show-current)" = main ] || die "not on main"
  git -C "$REPO" fetch -q origin main
  [ "$(git -C "$REPO" rev-parse main)" = "$(git -C "$REPO" rev-parse origin/main)" ] \
    || die "main and origin/main differ; push or pull first"

  [ -n "$tag" ] || tag=$(next_tag)
  if git -C "$REPO" rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "Using existing tag $tag at $(git -C "$REPO" rev-parse --short "$tag^{commit}")"
  else
    git -C "$REPO" tag -a "$tag" -m "Insider ${tag#insider-}" main
    echo "Created local tag $tag at $(git -C "$REPO" rev-parse --short main)"
  fi

  local wc_id etherscan
  wc_id=$(xcconfig_value "$REPO/Planet/local.xcconfig" WALLETCONNECTV2_PROJECT_ID)
  etherscan=$(xcconfig_value "$REPO/Planet/local.xcconfig" ETHERSCAN_API_TOKEN)
  [ -n "$wc_id" ] && [ -n "$etherscan" ] || die "WALLETCONNECTV2_PROJECT_ID or ETHERSCAN_API_TOKEN missing in Planet/local.xcconfig"

  step "Checking out $tag in $SRC"
  mkdir -p "$WORKSPACE"
  if [ -d "$SRC" ]; then
    git -C "$SRC" checkout -q --detach "$tag"
    git -C "$SRC" clean -q -ffdx
  else
    git -C "$REPO" worktree add -q --detach "$SRC" "$tag"
  fi
  git -C "$SRC" lfs pull

  local out
  out=$(out_dir "$tag")
  rm -rf "$out"
  mkdir -p "$out"

  step "Resolving packages"
  xcodebuild -project "$SRC/Planet.xcodeproj" -scheme Planet -derivedDataPath "$DERIVED_DATA" \
    -resolvePackageDependencies -onlyUsePackageVersionsFromResolvedFile > "$out/resolve.log" 2>&1 \
    || { tail -20 "$out/resolve.log"; die "package resolution failed"; }

  step "Archiving (log: $out/archive.log)"
  xcodebuild archive -project "$SRC/Planet.xcodeproj" -scheme Planet -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$out/Planet.xcarchive" \
    -derivedDataPath "$DERIVED_DATA" -allowProvisioningUpdates \
    PLANET_ENABLE_APPLE_INTELLIGENCE=NO \
    PLANET_APP_ICON_NAME=AppIcon-Insider \
    SPARKLE_UPDATE_FEED_URL="$FEED_URL" \
    WALLETCONNECTV2_PROJECT_ID="$wc_id" \
    ETHERSCAN_API_TOKEN="$etherscan" > "$out/archive.log" 2>&1 \
    || { grep -E 'error:|BUILD FAILED|ARCHIVE FAILED' "$out/archive.log" | head -20; die "archive failed"; }

  local archived_app=$out/Planet.xcarchive/Products/Applications/Planet.app
  local info=$archived_app/Contents/Info.plist
  step "Checking the archived app"
  [ "$(plist "$info" SUFeedURL)" = "$FEED_URL" ] || die "SUFeedURL is $(plist "$info" SUFeedURL)"
  [ "$(plist "$info" CFBundleIconName)" = AppIcon-Insider ] || die "icon is $(plist "$info" CFBundleIconName)"
  [ "$(plist "$info" WALLETCONNECTV2_PROJECT_ID)" = "$wc_id" ] || die "WalletConnect project ID not set"
  [ "$(plist "$info" ETHERSCAN_API_TOKEN)" = "$etherscan" ] || die "Etherscan token not set"
  echo "Version $(plist "$info" CFBundleShortVersionString) ($(plist "$info" CFBundleVersion)), feed, icon and API keys OK"

  step "Signing Sparkle and CodeMirror with Developer ID"
  local app=$out/to-be-signed/$APP_NAME.app
  mkdir -p "$out/to-be-signed"
  ditto "$archived_app" "$app"
  local sparkle=$app/Contents/Frameworks/Sparkle.framework/Versions/B
  for item in "$sparkle/XPCServices/Installer.xpc" "$sparkle/XPCServices/Downloader.xpc" "$sparkle/Autoupdate" \
    "$sparkle/Sparkle" "$sparkle/Updater.app" "$app/Contents/Frameworks/Sparkle.framework" \
    "$app/Contents/Frameworks/CodeMirror-SwiftUI.framework"; do
    xcrun codesign --options runtime --deep --force --timestamp --sign "$SIGN_IDENTITY" "$item" > /dev/null 2>&1 \
      || die "codesign failed for $item"
  done
  find "$app" -name '._*' -delete
  xcrun codesign --verify --deep --strict "$app" || die "signature check failed"

  step "Notarizing (log: $out/notarize.log)"
  ditto -c -k --keepParent --sequesterRsrc "$app" "$out/$APP_NAME-notarize.zip"
  xcrun notarytool submit "$out/$APP_NAME-notarize.zip" --keychain-profile "$NOTARY_PROFILE" \
    --wait --timeout 30m > "$out/notarize.log" 2>&1 || true
  grep -q 'status: Accepted' "$out/notarize.log" || { cat "$out/notarize.log"; die "notarization was not accepted"; }
  rm "$out/$APP_NAME-notarize.zip"
  xcrun stapler staple "$app" > /dev/null
  xcrun stapler validate "$app" > /dev/null || die "staple validation failed"
  spctl --assess --type execute "$app" || die "Gatekeeper rejected the app"
  find "$app" -name '._*' -delete

  step "Zipping"
  ditto -c -k --keepParent --sequesterRsrc "$app" "$out/$APP_NAME.zip"
  ditto -c -k --keepParent --sequesterRsrc "$out/Planet.xcarchive/dSYMs/Planet.app.dSYM" "$out/$APP_NAME.app.dSYM.zip"

  step "Making appcast.xml"
  local bin appcast_dir=$out/appcast
  bin=$(sparkle_bin)
  mkdir -p "$appcast_dir"
  cp "$out/$APP_NAME.zip" "$appcast_dir/"
  "$bin/generate_appcast" --download-url-prefix "$DOWNLOAD_BASE/$tag/" --link "$WEBSITE_LINK" \
    --full-release-notes-url "$RELEASE_NOTES_URL" -o "$appcast_dir/appcast.xml" "$appcast_dir"
  xmlstarlet ed --inplace -s "/rss/channel/item" -t elem -n "sparkle:releaseNotesLink" -v "$RELEASE_NOTES_URL" \
    "$appcast_dir/appcast.xml"
  check_appcast "$tag"

  step "Built $tag"
  ls -l "$out/$APP_NAME.zip" "$out/$APP_NAME.app.dSYM.zip" "$appcast_dir/appcast.xml"
  echo
  echo "Changes from the live appcast:"
  diff <(curl -fsS "$FEED_URL") "$appcast_dir/appcast.xml" || true
}

check_appcast() {
  local tag=$1 out bin xml url length signature build
  out=$(out_dir "$tag")
  xml=$out/appcast/appcast.xml
  bin=$(sparkle_bin)
  build=$(plist "$out/to-be-signed/$APP_NAME.app/Contents/Info.plist" CFBundleVersion)
  enclosure() { xmlstarlet sel -N sparkle=http://www.andymatuschak.org/xml-namespaces/sparkle -t -v "/rss/channel/item/enclosure/@$1" "$xml"; }
  url=$(enclosure url)
  length=$(enclosure length)
  signature=$(enclosure sparkle:edSignature)
  [ "$url" = "$DOWNLOAD_BASE/$tag/$APP_NAME.zip" ] || die "enclosure URL is $url"
  [ "$length" = "$(stat -f %z "$out/$APP_NAME.zip")" ] || die "enclosure length does not match the zip"
  [ "$(xmlstarlet sel -N sparkle=http://www.andymatuschak.org/xml-namespaces/sparkle -t -v '/rss/channel/item/sparkle:version' "$xml")" = "$build" ] \
    || die "sparkle:version does not match build $build"
  "$bin/sign_update" --verify "$out/$APP_NAME.zip" "$signature" || die "EdDSA signature does not verify"
  echo "appcast OK: build $build, $url, $length bytes, signature verified"
}

rclone_spaces() {
  RCLONE_CONFIG_SPACES_TYPE=s3 \
  RCLONE_CONFIG_SPACES_PROVIDER=DigitalOcean \
  RCLONE_CONFIG_SPACES_ENDPOINT=$SPACE_ENDPOINT \
  RCLONE_CONFIG_SPACES_ACCESS_KEY_ID=$(security find-generic-password -a access_key -s planet-release.spaces.planetable -w) \
  RCLONE_CONFIG_SPACES_SECRET_ACCESS_KEY=$(security find-generic-password -a secret_key -s planet-release.spaces.planetable -w) \
  rclone --config /dev/null --s3-no-check-bucket "$@"
}

push_tag() {
  local tag=${1:?tag}
  git -C "$REPO" push origin "refs/tags/$tag"
}

github() {
  local tag=${1:?tag} out
  out=$(out_dir "$tag")
  git -C "$REPO" ls-remote --exit-code --tags origin "refs/tags/$tag" > /dev/null || die "push the tag first"
  gh release create "$tag" --repo Planetable/Planet --prerelease --verify-tag --title "$tag" --notes "" \
    "$out/$APP_NAME.zip" "$out/$APP_NAME.app.dSYM.zip"
}

spaces() {
  local tag=${1:?tag} out token
  out=$(out_dir "$tag")
  check_appcast "$tag"
  step "Uploading $APP_NAME.zip"
  rclone_spaces copyto "$out/$APP_NAME.zip" "spaces:$SPACE/planet-insider/$tag/$APP_NAME.zip" \
    --s3-acl public-read --header-upload "Content-Type: application/zip"
  step "Uploading appcast.xml"
  rclone_spaces copyto "$out/appcast/appcast.xml" "spaces:$SPACE/planet-insider/appcast.xml" \
    --s3-acl public-read --header-upload "Content-Type: application/xml"
  step "Purging appcast.xml from the CDN"
  token=$(security find-generic-password -a planetable -s planet-release.digitalocean-api -w)
  curl -fsS -X DELETE -H "Content-Type: application/json" -H "Authorization: Bearer $token" \
    -d '{"files": ["planet-insider/appcast.xml"]}' \
    "https://api.digitalocean.com/v2/cdn/endpoints/$CDN_ENDPOINT_ID/cache"
  echo "purge requested"
}

verify() {
  local tag=${1:?tag} out live expected
  out=$(out_dir "$tag")
  expected=$(plist "$out/to-be-signed/$APP_NAME.app/Contents/Info.plist" CFBundleVersion)
  live=$(curl -fsS "$FEED_URL" | xmlstarlet sel -N sparkle=http://www.andymatuschak.org/xml-namespaces/sparkle \
    -t -v '/rss/channel/item/sparkle:version')
  [ "$live" = "$expected" ] || die "live appcast has build $live, expected $expected (CDN may still be purging)"
  local url=$DOWNLOAD_BASE/$tag/$APP_NAME.zip size
  size=$(curl -fsSI "$url" | awk 'tolower($1)=="content-length:" {print $2}' | tr -d '\r')
  [ "$size" = "$(stat -f %z "$out/$APP_NAME.zip")" ] || die "download size $size does not match the zip"
  echo "live: appcast build $live, $url ($size bytes)"
}

case ${1:-} in
  build) build "${2:-}" ;;
  push-tag) push_tag "${2:-}" ;;
  github) github "${2:-}" ;;
  spaces) spaces "${2:-}" ;;
  verify) verify "${2:-}" ;;
  check-appcast) check_appcast "${2:-}" ;;
  *) sed -n '3,10p' "$0"; exit 1 ;;
esac
