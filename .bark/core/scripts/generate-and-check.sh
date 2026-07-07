#!/bin/sh

set -eu

PKL=${PKL:-pkl}
CORE_DIR=.bark/core
GENERATED_DIR=$CORE_DIR/generated

if [ ! -f .bark/registry.pkl ] || [ ! -f PklProject ]; then
  echo "error: run this script from the repo/ directory" >&2
  exit 1
fi

mkdir -p "$GENERATED_DIR"

"$PKL" run --module-path . "$CORE_DIR/scripts/render-schema.pkl" \
  --output "$GENERATED_DIR/ProjectionSchema.pkl" \
  --path-prefix modulepath:/.bark/

"$PKL" run --module-path . "$CORE_DIR/scripts/preprocess.pkl" \
  --output "$GENERATED_DIR/projection-meta.pkl"

"$PKL" run --module-path . "$CORE_DIR/scripts/project.pkl" \
  --output "$GENERATED_DIR/projection.pkl" \
  --path-prefix ../../../

"$PKL" eval --module-path . "$GENERATED_DIR/projection-meta.pkl" >/dev/null
"$PKL" eval --module-path . "$GENERATED_DIR/projection.pkl" >/dev/null

"$PKL" run --module-path . "$CORE_DIR/scripts/postprocess.pkl" \
  --output "$GENERATED_DIR/postprocess-output.pcf"

echo "Generated and validated projection, metadata, and postprocess artifacts."
