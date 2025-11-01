#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/magnum357i/mpv-dualsubtitles"
PLUGIN_NAME="dualsubtitles"
CONFIG_DIR="$HOME/.config/mpv"
TMP_DIR="/tmp/gitmpv$PLUGIN_NAME"

# checking dependices...

dependencies=(git ffmpeg)
missing_dependencies=false

for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "Error! '$dep' command not found. Please install it first."
	    missing_dependencies=true
    fi
done

if [ "$missing_dependencies" = true ]; then
    exit 1
fi

# checking config path...

if [ ! -d "$CONFIG_DIR" ]; then
    echo "Error! MPV config directory not found: $CONFIG_DIR"
    exit 1
fi

# reset

[ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
[ -d "$CONFIG_DIR/scripts/$PLUGIN_NAME" ] && rm -rf "$CONFIG_DIR/scripts/$PLUGIN_NAME"

# install

git clone --depth 1 "$REPO_URL" "$TMP_DIR"
mkdir -p "$CONFIG_DIR/scripts"
mkdir -p "$CONFIG_DIR/script-opts"
mv "$TMP_DIR/scripts/$PLUGIN_NAME" "$CONFIG_DIR/scripts"
[ ! -f "$CONFIG_DIR/script-opts/$PLUGIN_NAME.conf" ] && mv "$TMP_DIR/script-opts/$PLUGIN_NAME.conf" "$CONFIG_DIR/script-opts"

echo "Done!"