#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${TARGET_URL:-https://danielfoojunwei.com/}"
OUTPUT_DIR="${OUTPUT_DIR:-site}"
TMP_DIR="${TMP_DIR:-.mirror-tmp}"

# Include known Squarespace/CDN hosts so assets are mirrored with the pages.
MIRROR_DOMAINS="${MIRROR_DOMAINS:-danielfoojunwei.com,www.danielfoojunwei.com,static1.squarespace.com,images.squarespace-cdn.com,static.wixstatic.com}"

rm -rf "$TMP_DIR" "$OUTPUT_DIR"
mkdir -p "$TMP_DIR" "$OUTPUT_DIR"

echo "Mirroring $TARGET_URL ..."
echo "Domains: $MIRROR_DOMAINS"

# wget may return exit code 8 for server-side HTTP errors on some resources
# even when a usable full snapshot is produced. We validate output afterwards.
WGET_EXIT=0
set +e
wget \
  --mirror \
  --page-requisites \
  --adjust-extension \
  --convert-links \
  --span-hosts \
  --no-parent \
  --execute robots=off \
  --tries=5 \
  --waitretry=2 \
  --timeout=30 \
  --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36" \
  --domains "$MIRROR_DOMAINS" \
  --directory-prefix "$TMP_DIR" \
  "$TARGET_URL"
WGET_EXIT=$?
set -e

if [[ "$WGET_EXIT" -ne 0 && "$WGET_EXIT" -ne 8 ]]; then
  echo "Mirror failed: wget exited with code $WGET_EXIT" >&2
  exit "$WGET_EXIT"
fi

if [[ "$WGET_EXIT" -eq 8 ]]; then
  echo "Warning: wget exited with code 8 (some resources failed). Verifying snapshot integrity..."
fi

SOURCE_PATH=""
if [[ -d "$TMP_DIR/danielfoojunwei.com" ]]; then
  SOURCE_PATH="$TMP_DIR/danielfoojunwei.com"
elif [[ -d "$TMP_DIR/www.danielfoojunwei.com" ]]; then
  SOURCE_PATH="$TMP_DIR/www.danielfoojunwei.com"
else
  echo "Could not find mirrored domain folder in $TMP_DIR" >&2
  exit 1
fi

cp -a "$SOURCE_PATH/." "$OUTPUT_DIR/"

if [[ ! -f "$OUTPUT_DIR/index.html" && -f "$OUTPUT_DIR/index.html.html" ]]; then
  mv "$OUTPUT_DIR/index.html.html" "$OUTPUT_DIR/index.html"
fi

if [[ ! -f "$OUTPUT_DIR/index.html" ]]; then
  echo "Mirror incomplete: missing $OUTPUT_DIR/index.html" >&2
  exit 1
fi

HTML_COUNT="$(find "$OUTPUT_DIR" -type f \( -name '*.html' -o -name '*.htm' \) | wc -l | tr -d ' ')"
ASSET_COUNT="$(find "$OUTPUT_DIR" -type f \( -name '*.css' -o -name '*.js' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name '*.svg' -o -name '*.woff' -o -name '*.woff2' \) | wc -l | tr -d ' ')"

if [[ "$HTML_COUNT" -lt 1 ]]; then
  echo "Mirror incomplete: no HTML files found." >&2
  exit 1
fi

echo "Mirror verification: $HTML_COUNT HTML files, $ASSET_COUNT assets"
rm -rf "$TMP_DIR"

echo "Mirror completed. Files are in $OUTPUT_DIR"
