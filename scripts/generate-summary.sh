#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SRC_DIR="$ROOT_DIR/src"
readonly SIDEBAR_FILE="$SRC_DIR/sidebar.md"
readonly EXCLUDED_FILES=("SUMMARY.md" "sidebar.md")

declare -i FILE_COUNT=0

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_success() {
    echo "[SUCCESS] $*"
}

validate_environment() {
    if [[ ! -d "$SCRIPT_DIR" ]]; then
        log_error "Script directory not found: $SCRIPT_DIR"
        exit 1
    fi

    if [[ ! -d "$SRC_DIR" ]]; then
        log_error "Source directory not found: $SRC_DIR"
        exit 1
    fi

    if [[ ! -w "$SRC_DIR" ]]; then
        log_error "Cannot write to source directory: $SRC_DIR"
        exit 1
    fi

    if ! command -v find &> /dev/null; then
        log_error "Required command 'find' not found"
        exit 1
    fi

    if ! command -v awk &> /dev/null; then
        log_error "Required command 'awk' not found"
        exit 1
    fi
}

is_excluded() {
    local filename="$1"
    local excluded
    for excluded in "${EXCLUDED_FILES[@]}"; do
        if [[ "${filename,,}" == "${excluded,,}" ]]; then
            return 0
        fi
    done
    return 1
}

convert_to_title_case() {
    local text="$1"
    echo "$text" | tr '-' ' ' | awk '{
        for(i=1; i<=NF; i++) {
            $i = toupper(substr($i, 1, 1)) tolower(substr($i, 2))
        }
        print
    }'
}

extract_title() {
    local filepath="$1"
    local filename
    local parent_dir
    local title

    filename=$(basename "$filepath" .md)
    parent_dir=$(basename "$(dirname "$filepath")")

    if [[ "${filename,,}" == "readme" ]]; then
        title=$(convert_to_title_case "$parent_dir")
    else
        title=$(convert_to_title_case "$filename")
    fi

    echo "$title"
}

# Proses direktori secara rekursif dan tulis ke file temp
process_directory() {
    local dir="$1"               # path relatif terhadap SRC_DIR (mis: "" untuk root, "python" untuk subdirektori)
    local depth="$2"             # kedalaman saat ini (0 untuk root)
    local temp_file="$3"         # file temporary untuk menulis output
    local full_path="$SRC_DIR/$dir"
    local indent=$(printf '%*s' $((depth * 4)) '')   # 4 spasi per level

    # 1. Tulis item untuk direktori ini (dari file readme.md jika ada)
    if [[ -f "$full_path/readme.md" ]]; then
        local title
        title=$(extract_title "$full_path/readme.md")
        local link="./$dir/readme.md"
        echo "${indent}- [${title}](${link})" >> "$temp_file"
        ((FILE_COUNT++)) || true
    fi

    # Kumpulkan semua file .md (kecuali readme) dan subdirektori dalam direktori ini
    local items=()
    while IFS= read -r -d '' item; do
        items+=("$item")
    done < <(find "$full_path" -maxdepth 1 -mindepth 1 \( -type f -name "*.md" -o -type d \) -print0 | sort -z)

    local files=()
    local dirs=()
    for item in "${items[@]}"; do
        local base
        base=$(basename "$item")
        if [[ -f "$item" && "$base" == "readme.md" ]]; then
            continue   # sudah diproses di atas
        elif [[ -f "$item" && "$base" == *.md ]]; then
            if is_excluded "$base"; then
                continue
            fi
            files+=("$item")
        elif [[ -d "$item" ]]; then
            dirs+=("$item")
        fi
    done

    # 2. Tulis item untuk file-file .md biasa (bukan readme)
    for file in "${files[@]}"; do
        local base
        base=$(basename "$file" .md)
        local title
        title=$(convert_to_title_case "$base")
        local rel_path="${file#$SRC_DIR/}"
        local link="./$rel_path"
        echo "${indent}    - [${title}](${link})" >> "$temp_file"
        ((FILE_COUNT++)) || true
    done

    # 3. Proses subdirektori secara rekursif
    for subdir in "${dirs[@]}"; do
        local rel_subdir="${subdir#$SRC_DIR/}"
        process_directory "$rel_subdir" $((depth + 1)) "$temp_file"
    done
}

generate_sidebar() {
    local temp_file
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT

    # Tulis header
    {
        echo "# Summary"
        echo ""
    } > "$temp_file"

    # Proses root direktori
    process_directory "" 0 "$temp_file"

    # Pindahkan hasil ke file tujuan
    mv "$temp_file" "$SIDEBAR_FILE"
    trap - EXIT
}

display_summary() {
    echo ""
    echo "========================================"
    echo "           SIDEBAR GENERATION           "
    echo "========================================"
    echo "  Source Directory : $SRC_DIR"
    echo "  Output File      : $SIDEBAR_FILE"
    echo "  Total Entries    : $FILE_COUNT"
    echo "  Excluded Files   : ${EXCLUDED_FILES[*]}"
    echo "========================================"
}

main() {
    log_info "Starting sidebar generation..."

    validate_environment
    generate_sidebar

    log_success "Sidebar generated successfully"
    display_summary
}

main "$@"