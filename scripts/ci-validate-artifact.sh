#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${SOURCEMOD_ARTIFACT_DIR:-$ROOT_DIR/dist/sourcemod/artifact}"

if [[ ! -d "$ARTIFACT_DIR" ]]; then
  echo "SourceMod artifact directory not found at $ARTIFACT_DIR" >&2
  exit 1
fi

python3 - "$ARTIFACT_DIR" <<'PY'
import os
import sys

artifact_dir = sys.argv[1]

plugin_dir = os.path.join(artifact_dir, "addons", "sourcemod", "plugins", "callvote")
expected_plugins = {
    "callvotemanager.smx",
    "callvote_kicklimit.smx",
    "callvote_bans.smx",
    "callvote_bans_adminmenu.smx",
}

if not os.path.isdir(plugin_dir):
    raise SystemExit(f"Missing plugin directory: {plugin_dir}")

plugins = {entry for entry in os.listdir(plugin_dir) if os.path.isfile(os.path.join(plugin_dir, entry))}
if plugins != expected_plugins:
    raise SystemExit(f"Unexpected compiled plugins: {sorted(plugins)}")

root_plugin_dir = os.path.join(artifact_dir, "addons", "sourcemod", "plugins")
for plugin_name in expected_plugins:
    if os.path.isfile(os.path.join(root_plugin_dir, plugin_name)):
        raise SystemExit(f"Plugin should not exist at root plugins directory: {plugin_name}")

include_dir = os.path.join(artifact_dir, "addons", "sourcemod", "scripting", "include")
expected_includes = ["callvote_bans.inc", "callvote_stock.inc", "callvotemanager.inc"]
include_entries = sorted(entry for entry in os.listdir(include_dir) if os.path.isfile(os.path.join(include_dir, entry)))
if include_entries != expected_includes:
    raise SystemExit(f"Unexpected public includes: {include_entries}")

config_dir = os.path.join(artifact_dir, "addons", "sourcemod", "configs")
sql_init_dir = os.path.join(config_dir, "sql-init-callvote")
if not os.path.isdir(sql_init_dir):
    raise SystemExit("Missing sql-init-callvote directory")

translations_dir = os.path.join(artifact_dir, "addons", "sourcemod", "translations")
expected_translations = [
    os.path.join(translations_dir, "callvote_bans_adminmenu.phrases.txt"),
    os.path.join(translations_dir, "callvote_bans.phrases.txt"),
    os.path.join(translations_dir, "callvote_common.phrases.txt"),
    os.path.join(translations_dir, "callvote_kicklimit.phrases.txt"),
    os.path.join(translations_dir, "callvote_manager.phrases.txt"),
]

for translation_path in expected_translations:
    if not os.path.isfile(translation_path):
        raise SystemExit(f"Missing translation file: {translation_path}")

print("ARTIFACT_VALIDATION_OK")
PY
