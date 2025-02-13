#!/bin/bash
#
# Usage: ./install.sh <script-file>
#
# This script installs a given script and sets up an alias.
# The alias is automatically derived from the file’s basename (minus its extension).
#
# For .js files, it copies the file and creates an alias that runs it with node:
#   alias filename='node <destination>/filename.js'
#
# For .rs files, it compiles the file with rustc, places the binary in the destination,
# and creates an alias to run the binary.
#
# For other files, it simply copies the file and creates an alias.
#
# If /usr/local/bin is not writable, the script will install the file in the current directory.
#

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <script-file>"
    exit 1
fi

SCRIPT_FILE="$1"

if [ ! -f "$SCRIPT_FILE" ]; then
    echo "Error: File '$SCRIPT_FILE' not found."
    exit 1
fi

ALIAS_NAME=$(basename "$SCRIPT_FILE")
ALIAS_NAME="${ALIAS_NAME%.*}"

DEFAULT_DEST="/usr/local/bin"
if [ -d "$DEFAULT_DEST" ] && [ -w "$DEFAULT_DEST" ]; then
    DEST_DIR="$DEFAULT_DEST"
else
    echo "Warning: $DEFAULT_DEST is not writable. Using current directory ($(pwd)) as destination."
    DEST_DIR="$(pwd)"
fi

if [[ "$SHELL" == */zsh ]]; then
    CONFIG_FILE="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
    CONFIG_FILE="$HOME/.bash_profile"
else
    CONFIG_FILE="$HOME/.bash_profile"
fi

EXT="${SCRIPT_FILE##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
ALIAS_LINE=""
case "$EXT_LOWER" in
    js)
        DEST_PATH="$DEST_DIR/$ALIAS_NAME.js"
        cp "$SCRIPT_FILE" "$DEST_PATH"
        chmod +x "$DEST_PATH"
        echo "JavaScript file copied to $DEST_PATH and made executable."
        ALIAS_LINE="alias $ALIAS_NAME='node $DEST_PATH'"
        ;;
    rs)
        DEST_PATH="$DEST_DIR/$ALIAS_NAME"
        if ! command -v rustc &>/dev/null; then
            echo "Error: rustc is not installed. Please install the Rust toolchain first."
            exit 1
        fi
        rustc "$SCRIPT_FILE" -o "$DEST_PATH"
        if [ $? -ne 0 ]; then
            echo "Error: rustc failed to compile $SCRIPT_FILE"
            exit 1
        fi
        chmod +x "$DEST_PATH"
        echo "Rust file compiled to $DEST_PATH."
        ALIAS_LINE="alias $ALIAS_NAME='$DEST_PATH'"
        ;;
    *)
        DEST_PATH="$DEST_DIR/$ALIAS_NAME"
        cp "$SCRIPT_FILE" "$DEST_PATH"
        chmod +x "$DEST_PATH"
        echo "File copied to $DEST_PATH and made executable."
        ALIAS_LINE="alias $ALIAS_NAME='$DEST_PATH'"
        ;;
esac

if grep -Fxq "$ALIAS_LINE" "$CONFIG_FILE"; then
    echo "Alias already exists in $CONFIG_FILE."
else
    echo "$ALIAS_LINE" >> "$CONFIG_FILE"
    echo "Alias added to $CONFIG_FILE."
    echo "Reload your shell (or run 'source $CONFIG_FILE') to use the new alias."
fi

echo "Installation complete. You can now use the command '$ALIAS_NAME' from anywhere."
