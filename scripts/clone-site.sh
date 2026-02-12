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

# wget returns non-zero on HTTP errors (e.g. 500s from CDN) even when most
# files download fine.  Capture its exit code and only abort on fatal failures
# (exit code 1-3 = generic/parse/IO errors).  Code 8 = server error responses,
# which are expected for some stale Squarespace CDN assets.
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
  echo "wget failed with exit code $WGET_EXIT" >&2
  exit 1
fi

DOMAIN_DIR=""
if [[ -d "$TMP_DIR/danielfoojunwei.com" ]]; then
  DOMAIN_DIR="danielfoojunwei.com"
elif [[ -d "$TMP_DIR/www.danielfoojunwei.com" ]]; then
  DOMAIN_DIR="www.danielfoojunwei.com"
else
  echo "Could not find mirrored domain folder in $TMP_DIR" >&2
  exit 1
fi

# Copy the entire mirror tree (all domains) so that --convert-links relative
# paths to CDN hosts (static1.squarespace.com, images.squarespace-cdn.com, etc.)
# remain valid.
cp -a "$TMP_DIR/." "$OUTPUT_DIR/"

# Move the main domain's content to the root of OUTPUT_DIR so index.html is at
# the top level where Vercel expects it.
# First move CDN directories out of the way temporarily, then hoist domain files.
MAIN_DIR="$OUTPUT_DIR/$DOMAIN_DIR"

# Copy main domain contents to root (this may overwrite the domain dir itself)
cp -a "$MAIN_DIR/." "$OUTPUT_DIR/"

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
