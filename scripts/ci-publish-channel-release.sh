#!/usr/bin/env bash
set -euo pipefail

tag="$1"
title="$2"
asset="$3"
prerelease="$4"
[[ -f "$asset" ]] || { echo "Missing release asset: $asset" >&2; exit 1; }
case "$tag:$prerelease" in
  channel/develop:true|channel/latest:false) ;;
  *) echo "Invalid release channel" >&2; exit 1 ;;
esac
latest=--latest=false
[[ "$prerelease" == true ]] || latest=--latest
if gh release view "$tag" >/dev/null 2>&1; then
  # Preserve the existing target; only the channel tag moves in the preceding step.
  gh release edit "$tag" --title "$title" --prerelease="$prerelease" "$latest"
  gh release upload "$tag" "$asset" --clobber
else
  gh release create "$tag" "$asset" --title "$title" --verify-tag --prerelease="$prerelease" "$latest"
fi
