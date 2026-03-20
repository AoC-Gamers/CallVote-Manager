#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${RUNNER_TEMP:-$ROOT_DIR/.tmp}/sourcemod-build"
DIST_DIR="$ROOT_DIR/dist/sourcemod"
ARTIFACT_DIR="$DIST_DIR/artifact"
SOURCEMOD_ARCHIVE_URL="${SOURCEMOD_ARCHIVE_URL:?SOURCEMOD_ARCHIVE_URL is required}"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$ARTIFACT_DIR"

echo "Downloading SourceMod compiler package..."
curl -fsSL "$SOURCEMOD_ARCHIVE_URL" -o "$WORK_DIR/sourcemod.tar.gz"
tar -xzf "$WORK_DIR/sourcemod.tar.gz" -C "$WORK_DIR"

SOURCEMOD_DIR="$WORK_DIR"
SPCOMP_BIN="$SOURCEMOD_DIR/addons/sourcemod/scripting/spcomp"
SOURCEMOD_INCLUDE_DIR="$SOURCEMOD_DIR/addons/sourcemod/scripting/include"
LOCAL_INCLUDE_DIR="$ROOT_DIR/addons/sourcemod/scripting/include"
PACKAGE_SM_DIR="$ARTIFACT_DIR/addons/sourcemod"
PACKAGE_PLUGIN_DIR="$PACKAGE_SM_DIR/plugins/callvote"
PACKAGE_INCLUDE_DIR="$PACKAGE_SM_DIR/scripting/include"
PACKAGE_CONFIG_DIR="$PACKAGE_SM_DIR/configs"
PACKAGE_TRANSLATIONS_DIR="$PACKAGE_SM_DIR/translations"
COMPILE_LOG="$ARTIFACT_DIR/compile.log"

mkdir -p \
  "$PACKAGE_PLUGIN_DIR" \
  "$PACKAGE_INCLUDE_DIR" \
  "$PACKAGE_CONFIG_DIR" \
  "$PACKAGE_TRANSLATIONS_DIR"

: > "$COMPILE_LOG"

for include_file in \
  builtinvotes_stocks.inc \
  left4dhooks.inc \
  left4dhooks_anim.inc \
  left4dhooks_silver.inc \
  left4dhooks_lux_library.inc \
  left4dhooks_stocks.inc \
  localizer.inc
do
  if [[ ! -f "$LOCAL_INCLUDE_DIR/$include_file" ]]; then
    echo "Missing required local include: $LOCAL_INCLUDE_DIR/$include_file" >&2
    exit 1
  fi
done

compile_plugin() {
  local source_file="$1"
  local output_file="$2"

  echo "Compiling $(basename "$source_file")..."
  "$SPCOMP_BIN" \
    "$source_file" \
    -i"$LOCAL_INCLUDE_DIR" \
    -i"$SOURCEMOD_INCLUDE_DIR" \
    -o"$output_file" \
    2>&1 | tee -a "$COMPILE_LOG"
}

compile_plugin \
  "$ROOT_DIR/addons/sourcemod/scripting/callvote_manager.sp" \
  "$PACKAGE_PLUGIN_DIR/callvotemanager.smx"

compile_plugin \
  "$ROOT_DIR/addons/sourcemod/scripting/callvote_kicklimit.sp" \
  "$PACKAGE_PLUGIN_DIR/callvote_kicklimit.smx"

compile_plugin \
  "$ROOT_DIR/addons/sourcemod/scripting/callvote_bans.sp" \
  "$PACKAGE_PLUGIN_DIR/callvote_bans.smx"

compile_plugin \
  "$ROOT_DIR/addons/sourcemod/scripting/callvote_bans_adminmenu.sp" \
  "$PACKAGE_PLUGIN_DIR/callvote_bans_adminmenu.smx"

for plugin in callvotemanager callvote_kicklimit callvote_bans callvote_bans_adminmenu; do
  if [[ ! -f "$PACKAGE_PLUGIN_DIR/${plugin}.smx" ]]; then
    echo "Compiled plugin was not generated: ${plugin}.smx" >&2
    exit 1
  fi
done

cp "$ROOT_DIR/addons/sourcemod/scripting/include/callvotemanager.inc" "$PACKAGE_INCLUDE_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/include/callvote_stock.inc" "$PACKAGE_INCLUDE_DIR/"
cp "$ROOT_DIR/addons/sourcemod/scripting/include/callvote_bans.inc" "$PACKAGE_INCLUDE_DIR/"

cp -R "$ROOT_DIR/addons/sourcemod/configs/sql-init-callvote" "$PACKAGE_CONFIG_DIR/"

find "$ROOT_DIR/addons/sourcemod/translations" -type f \( -name 'callvote*.phrases.txt' -o -path '*/callvote*.phrases.txt' \) -print0 | while IFS= read -r -d '' translation_file; do
  relative_path="${translation_file#"$ROOT_DIR/addons/sourcemod/translations/"}"
  target_path="$PACKAGE_TRANSLATIONS_DIR/$relative_path"
  mkdir -p "$(dirname "$target_path")"
  cp "$translation_file" "$target_path"
done

echo "SourceMod artifacts generated in $ARTIFACT_DIR"
