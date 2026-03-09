#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOG_DIR="$SCRIPT_DIR/../src/blog"

to_title_case() {
    echo "$1" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1'
}

to_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9 -]//g' | sed -e 's/  */ /g' | sed -e 's/ /-/g' | sed -e 's/--*/-/g'
}

validate_title() {
    local title="$1"
    if [[ -z "$title" ]]; then
        echo "Error: Title cannot be empty." >&2
        exit 1
    fi
    if [[ ${#title} -gt 100 ]]; then
        echo "Error: Title exceeds maximum length of 100 characters." >&2
        exit 1
    fi
}

get_title() {
    if [[ $# -gt 0 ]]; then
        echo "$*"
    else
        read -r -p "Enter blog title: " INPUT_TITLE
        echo "$INPUT_TITLE"
    fi
}

main() {
    INPUT_TITLE=$(get_title "$@")
    validate_title "$INPUT_TITLE"

    SLUG_TITLE=$(to_slug "$INPUT_TITLE")
    FORMATTED_TITLE=$(to_title_case "$INPUT_TITLE")
    TIMESTAMP=$(date +"%d-%m-%y-%H-%M-%S")
    FILENAME="${TIMESTAMP}-${SLUG_TITLE}.md"
    FULL_PATH="$BLOG_DIR/$FILENAME"

    if [[ ! -d "$BLOG_DIR" ]]; then
        mkdir -p "$BLOG_DIR"
    fi

    if [[ -f "$FULL_PATH" ]]; then
        echo "Error: File already exists: $FILENAME" >&2
        exit 1
    fi

    echo "# $FORMATTED_TITLE" > "$FULL_PATH"

    RELATIVE_PATH="./blog/$FILENAME"

    echo ""
    echo "Blog created successfully."
    echo "File: $FILENAME"
    echo ""
    echo "Tip: Add this to your book.toml:"
    echo "$RELATIVE_PATH"
    echo ""
}

main "$@"