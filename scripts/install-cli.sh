#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <path to mork script> <command name>" >&2
    exit 64
fi

SOURCE="$1"
NAME="$2"

for dir in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        ln -sf "$SOURCE" "$dir/$NAME"
        echo "Command line tool: $dir/$NAME"
        case ":$PATH:" in
            *":$dir:"*) ;;
            *) echo "Add $dir to PATH to run $NAME from any folder." ;;
        esac
        exit 0
    fi
done

mkdir -p "$HOME/.local/bin"
ln -sf "$SOURCE" "$HOME/.local/bin/$NAME"
echo "Command line tool: $HOME/.local/bin/$NAME"
echo "Add $HOME/.local/bin to PATH to run $NAME from any folder."
