#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  update-flac-sidecars.sh [options] <album_dir>

Options:
  --artist NAME         Set ARTIST on all tracks
  --album NAME          Set ALBUM on all tracks
  --albumartist NAME    Set ALBUMARTIST on all tracks
  --date YYYY[-MM[-DD]] Set DATE on all tracks
  --genre NAME          Set GENRE on all tracks
  --disc N              Set DISCNUMBER on all tracks (default: keep existing)
  --m3u NAME            Output M3U8 filename (default: album.m3u8)
  --cue NAME            Output CUE filename (default: album.cue)
  --toc NAME            Output TOC filename (default: album.toc)
  --dry-run             Show actions without writing tags/files
  -h, --help            Show this help

Notes:
  - Requires metaflac.
  - CUE/TOC generation uses shntool if available.
  - Track titles are derived from filenames by stripping common numeric prefixes.
EOF
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: required command not found: $cmd" >&2
        exit 1
    }
}

title_from_filename() {
    local f="$1"
    local base
    base="$(basename "$f")"
    base="${base%.*}"

    # Strip common prefixes like:
    # 01 - Title
    # 01.Title
    # 1_ Title
    # 01) Title
    base="$(printf '%s' "$base" | sed -E 's/^[[:space:]]*[0-9]{1,3}[[:space:]_.-]*[)-]?[[:space:]]*//')"

    # Trim leading/trailing whitespace
    base="$(printf '%s' "$base" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    printf '%s' "$base"
}

set_tag() {
    local file="$1"
    local key="$2"
    local value="$3"
    local dry_run="$4"

    if [[ "$dry_run" == "1" ]]; then
        echo "metaflac --remove-tag=$key --set-tag=$key=$value \"$file\""
    else
        metaflac --remove-tag="$key" --set-tag="$key=$value" "$file"
    fi
}

ARTIST=""
ALBUM=""
ALBUMARTIST=""
DATE_TAG=""
GENRE=""
DISC=""
M3U_NAME="album.m3u8"
CUE_NAME="album.cue"
TOC_NAME="album.toc"
DRY_RUN=0

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --artist)
            ARTIST="${2:-}"; shift 2 ;;
        --album)
            ALBUM="${2:-}"; shift 2 ;;
        --albumartist)
            ALBUMARTIST="${2:-}"; shift 2 ;;
        --date)
            DATE_TAG="${2:-}"; shift 2 ;;
        --genre)
            GENRE="${2:-}"; shift 2 ;;
        --disc)
            DISC="${2:-}"; shift 2 ;;
        --m3u)
            M3U_NAME="${2:-}"; shift 2 ;;
        --cue)
            CUE_NAME="${2:-}"; shift 2 ;;
        --toc)
            TOC_NAME="${2:-}"; shift 2 ;;
        --dry-run)
            DRY_RUN=1; shift ;;
        -h|--help)
            usage; exit 0 ;;
        --)
            shift; break ;;
        -*)
            echo "ERROR: unknown option: $1" >&2
            usage
            exit 2 ;;
        *)
            POSITIONAL+=("$1"); shift ;;
    esac
done

if [[ ${#POSITIONAL[@]} -ne 1 ]]; then
    usage
    exit 2
fi

ALBUM_DIR="${POSITIONAL[0]}"
if [[ ! -d "$ALBUM_DIR" ]]; then
    echo "ERROR: not a directory: $ALBUM_DIR" >&2
    exit 1
fi

require_cmd metaflac

# Stable ordering for deterministic track numbers and M3U output
mapfile -d '' FLAC_FILES < <(find "$ALBUM_DIR" -maxdepth 1 -type f \( -iname '*.flac' \) -print0 | sort -z)

if [[ ${#FLAC_FILES[@]} -eq 0 ]]; then
    echo "ERROR: no FLAC files found in $ALBUM_DIR" >&2
    exit 1
fi

echo "Found ${#FLAC_FILES[@]} FLAC files"

track=1
for file in "${FLAC_FILES[@]}"; do
    title="$(title_from_filename "$file")"

    set_tag "$file" "TRACKNUMBER" "$track" "$DRY_RUN"
    set_tag "$file" "TITLE" "$title" "$DRY_RUN"

    if [[ -n "$ARTIST" ]]; then
        set_tag "$file" "ARTIST" "$ARTIST" "$DRY_RUN"
    fi
    if [[ -n "$ALBUM" ]]; then
        set_tag "$file" "ALBUM" "$ALBUM" "$DRY_RUN"
    fi
    if [[ -n "$ALBUMARTIST" ]]; then
        set_tag "$file" "ALBUMARTIST" "$ALBUMARTIST" "$DRY_RUN"
    fi
    if [[ -n "$DATE_TAG" ]]; then
        set_tag "$file" "DATE" "$DATE_TAG" "$DRY_RUN"
    fi
    if [[ -n "$GENRE" ]]; then
        set_tag "$file" "GENRE" "$GENRE" "$DRY_RUN"
    fi
    if [[ -n "$DISC" ]]; then
        set_tag "$file" "DISCNUMBER" "$DISC" "$DRY_RUN"
    fi

    track=$((track + 1))
done

# Always regenerate M3U8 from sorted filenames
M3U_PATH="$ALBUM_DIR/$M3U_NAME"
if [[ "$DRY_RUN" == "1" ]]; then
    echo "Would write M3U8: $M3U_PATH"
else
    {
        for file in "${FLAC_FILES[@]}"; do
            basename "$file"
        done
    } > "$M3U_PATH"
    echo "Wrote M3U8: $M3U_PATH"
fi

# CUE/TOC are optional: require shntool
if command -v shntool >/dev/null 2>&1; then
    CUE_PATH="$ALBUM_DIR/$CUE_NAME"
    TOC_PATH="$ALBUM_DIR/$TOC_NAME"

    if [[ "$DRY_RUN" == "1" ]]; then
        echo "Would write CUE: $CUE_PATH"
        echo "Would write TOC: $TOC_PATH"
    else
        (
            cd "$ALBUM_DIR"
            shntool cue ./*.flac > "$CUE_NAME"
            shntool toc ./*.flac > "$TOC_NAME"
        )
        echo "Wrote CUE: $CUE_PATH"
        echo "Wrote TOC: $TOC_PATH"
    fi
else
    echo "WARNING: shntool not found; skipped CUE/TOC generation" >&2
fi

echo "Done."
