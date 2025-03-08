#!/bin/sh
echo -ne '\033c\033]0;CSS436 - Final Project\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/wordwarzero.x86_64" "$@"
