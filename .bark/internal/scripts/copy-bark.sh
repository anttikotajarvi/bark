#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <target-root>"
  echo
  echo "Example:"
  echo "  $0 ../../client-repo"
  exit 1
fi

TARGET_ROOT="$1"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BARK_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCHEMA_REPO_ROOT="$(cd -- "$BARK_DIR/.." && pwd)"

SOURCE_BUNDLE="$SCHEMA_REPO_ROOT/bundle"
TARGET_BARK="$TARGET_ROOT/.bark"
TARGET_GENERATED="$TARGET_BARK/generated"

if [ ! -d "$BARK_DIR" ]; then
  echo "Error: source .bark directory not found: $BARK_DIR" >&2
  exit 1
fi

if [ ! -d "$SOURCE_BUNDLE" ]; then
  echo "Error: source bundle directory not found: $SOURCE_BUNDLE" >&2
  exit 1
fi

mkdir -p "$TARGET_ROOT"

# Replace the generated client .bark directory.
rm -rf "$TARGET_BARK"
cp -a "$BARK_DIR" "$TARGET_BARK"

# Copy schema repo bundle into the new .bark directory.
rm -rf "$TARGET_BARK/bundle"
cp -a "$SOURCE_BUNDLE" "$TARGET_BARK/bundle"

echo "Copied:"
echo "  $BARK_DIR -> $TARGET_BARK"
echo "  $SOURCE_BUNDLE -> $TARGET_BARK/bundle"

# Generate registry.pcf
pkl run $SCRIPT_DIR/registry.pkl -o $TARGET_GENERATED/registry.pcf