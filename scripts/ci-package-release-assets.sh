#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${SOURCEMOD_ARTIFACT_DIR:-$ROOT_DIR/dist/sourcemod/artifact}"
RELEASE_DIR="$ROOT_DIR/dist/release"
RELEASE_VERSION="${RELEASE_VERSION:?RELEASE_VERSION is required}"
ARCHIVE_BASENAME="callvote-manager-${RELEASE_VERSION}"
ARCHIVE_PATH="$RELEASE_DIR/${ARCHIVE_BASENAME}.zip"

if [[ ! -d "$ARTIFACT_DIR" ]]; then
  echo "SourceMod artifact directory not found at $ARTIFACT_DIR" >&2
  exit 1
fi

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

python3 - "$ARTIFACT_DIR" "$ARCHIVE_PATH" <<'PY'
import os
import sys
import zipfile

artifact_dir, archive_path = sys.argv[1], sys.argv[2]

with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for current_root, dirs, files in os.walk(artifact_dir):
        dirs.sort()
        files.sort()
        for file_name in files:
            source_path = os.path.join(current_root, file_name)
            archive_path_name = os.path.relpath(source_path, artifact_dir)
            archive.write(source_path, archive_path_name)
PY

echo "Release archive generated at $ARCHIVE_PATH"