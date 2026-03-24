#!/usr/bin/env bash

set -euo pipefail

TAG_NAME="${1:-${GITHUB_REF_NAME:-}}"

if [[ -z "$TAG_NAME" ]]; then
  echo "Release tag is required." >&2
  exit 1
fi

case "$TAG_NAME" in
  sourcemod/v*)
    component="sourcemod"
    version="${TAG_NAME#sourcemod/v}"
    basename="callvote-manager-${version}"
    release_name="SourceMod v${version}"
    ;;
  *)
    echo "Unsupported release tag '$TAG_NAME'. Use sourcemod/vX.Y.Z." >&2
    exit 1
    ;;
esac

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]]; then
  echo "Tag version '$version' is not valid SemVer." >&2
  exit 1
fi

prerelease="false"
if [[ "$version" == *-* ]]; then
  prerelease="true"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "component=$component"
    echo "version=$version"
    echo "basename=$basename"
    echo "release_name=$release_name"
    echo "prerelease=$prerelease"
  } >> "$GITHUB_OUTPUT"
else
  cat <<EOF
component=$component
version=$version
basename=$basename
release_name=$release_name
prerelease=$prerelease
EOF
fi