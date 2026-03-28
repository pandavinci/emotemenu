#!/bin/bash
# Creates a clean source zip for sharing/review

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT="emotemenu-source.zip"

rm -f "$OUTPUT"

zip -r "$OUTPUT" . \
    -x "mods-dll/*" \
    -x "releases/*" \
    -x ".git/*" \
    -x "*/obj/*" \
    -x "*/bin/*" \
    -x ".vscode/*" \
    -x "*.pdb" \
    -x "*.zip"

echo "Created: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
