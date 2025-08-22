#!/bin/bash
set -euo pipefail # Exit on error, treat unset variables as errors, and handle pipe failures

# --- Verbose Mode ---
VERBOSE=false

# --- Configuration ---
# User-configurable output directory
OUTPUT_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/00_inbox"
# Temporary file basename for subtitles (VIDEO_ID will be appended for uniqueness)
TEMP_SUB_BASENAME="temp_youtube_sub"

# Global variable for the actual temporary VTT file path, used by cleanup
ACTUAL_TEMP_VTT_FILE=""

# --- Helper Functions ---

# Cleanup function to remove temporary VTT file on exit
cleanup() {
    if [ -n "$ACTUAL_TEMP_VTT_FILE" ] && [ -f "$ACTUAL_TEMP_VTT_FILE" ]; then
        echo "Cleaning up temporary file: $ACTUAL_TEMP_VTT_FILE"
        rm -f "$ACTUAL_TEMP_VTT_FILE"
    fi
}
trap cleanup EXIT

# Function to convert string to snake_case
# 1. Replace non-alphanumeric characters with a single underscore.
# 2. Convert to lowercase.
# 3. Remove leading/trailing underscores.
# 4. Collapse multiple underscores to one.
to_snake_case() {
    if [ -z "$1" ]; then
        echo ""
        return
    fi
    echo "$1" | \
    sed -E 's/[^a-zA-Z0-9]+/_/g' | \
    tr '[:upper:]' '[:lower:]' | \
    sed -E 's/^_+//g' | \
    sed -E 's/_+$//g' | \
    sed -E 's/_+/_/g'
}

# --- Option Parsing ---
while getopts ":v" opt; do
  case ${opt} in
    v )
      VERBOSE=true
      ;;
    \? )
      # Allow other arguments to pass through for now, main check is $1 for URL
      ;;
  esac
done
shift $((OPTIND -1)) # Remove processed options

# --- Main Script ---

# Check for yt-dlp
if ! command -v yt-dlp &> /dev/null; then
    echo "Error: yt-dlp is not installed. Please install it first."
    exit 1
fi

# Check if a YouTube URL is provided
if [ -z "$1" ]; then
    echo "Usage: $0 [-v] <YouTube_URL>"
    echo "  -v: Enable verbose/debug output"
    echo "Example: $0 -v \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\""
    exit 1
fi
VIDEO_URL="$1"

echo "Fetching video information..."

if [ "$VERBOSE" = "true" ]; then
    echo "DEBUG: Script's PATH: $PATH"
    echo "DEBUG: yt-dlp path found by script's 'command -v': $(command -v yt-dlp)"
    echo "DEBUG: yt-dlp version found by script: $(yt-dlp --version 2>&1)"
    echo "DEBUG: About to call yt-dlp for info..."
fi

VIDEO_INFO_OUTPUT=$(yt-dlp --print "%(title)s\n%(channel)s\n%(id)s" --skip-download "$VIDEO_URL" 2>&1)
YT_DLP_INFO_EXIT_CODE=$?

if [ "$VERBOSE" = "true" ]; then
    echo "DEBUG: yt-dlp info call finished. Exit code: $YT_DLP_INFO_EXIT_CODE"
    echo "DEBUG: VIDEO_INFO_OUTPUT content (raw from yt-dlp call):"
    printf "%s\n" "$VIDEO_INFO_OUTPUT" # Using printf for safer multiline printing
    echo "DEBUG: --- end of VIDEO_INFO_OUTPUT ---"
fi

if [ $YT_DLP_INFO_EXIT_CODE -ne 0 ]; then
    echo "Error: yt-dlp failed to retrieve video information. Exit code: $YT_DLP_INFO_EXIT_CODE"
    echo "yt-dlp output:"
    echo "$VIDEO_INFO_OUTPUT"
    exit 1
fi

if [ "$VERBOSE" = "true" ]; then
    echo "DEBUG: About to read variables from VIDEO_INFO_OUTPUT using a while loop..."
fi
lines=()
while IFS= read -r line || [ -n "$line" ]; do # Process line even if no trailing newline, handles older bash
    lines+=("$line")
done <<< "$(printf '%b' "$VIDEO_INFO_OUTPUT")"

if [ "$VERBOSE" = "true" ]; then
    echo "DEBUG: Finished reading lines into an array. Number of lines: ${#lines[@]}"
fi

# Check if we got enough lines
if [ ${#lines[@]} -lt 3 ]; then
    echo "Error: Expected at least 3 lines (title, channel, ID) from yt-dlp, but got ${#lines[@]}."
    echo "yt-dlp output was:"
    printf "%s\n" "$VIDEO_INFO_OUTPUT" # Show the problematic output
    exit 1
fi

VIDEO_TITLE="${lines[0]}"
VIDEO_CHANNEL="${lines[1]}"
VIDEO_ID="${lines[2]}"

if [ "$VERBOSE" = "true" ]; then
    echo "DEBUG: Variables assigned from array."
    echo "DEBUG: VIDEO_TITLE='${VIDEO_TITLE}'"
    echo "DEBUG: VIDEO_CHANNEL='${VIDEO_CHANNEL}'"
    echo "DEBUG: VIDEO_ID='${VIDEO_ID}'"
fi

if [ -z "$VIDEO_TITLE" ] || [ -z "$VIDEO_CHANNEL" ] || [ -z "$VIDEO_ID" ]; then
    echo "Error: Failed to parse video title, channel, or ID from yt-dlp output."
    echo "yt-dlp output was:"
    echo "$VIDEO_INFO_OUTPUT"
    exit 1
fi

echo "Processing: $VIDEO_CHANNEL - $VIDEO_TITLE"

# Define the pattern for the downloaded subtitle file
# yt-dlp will append the language and format, e.g., .en.vtt
DOWNLOADED_SUB_PATH_PATTERN="${TEMP_SUB_BASENAME}_${VIDEO_ID}"

# Clean up any pre-existing temp file matching the pattern to avoid confusion
find . -maxdepth 1 -type f -name "${DOWNLOADED_SUB_PATH_PATTERN}.*.vtt" -delete

echo "Downloading auto-generated English subtitles..."
# Use yt-dlp to download auto-generated English subtitles in VTT format
# Outputting to a predictable filename pattern using the video ID
# Trying common English language codes

YT_DLP_SUB_DOWNLOAD_CMD=(yt-dlp --skip-download --write-auto-subs --sub-langs "en,en-US,en-GB" --sub-format vtt \
    -o "${DOWNLOADED_SUB_PATH_PATTERN}.%(ext)s" "$VIDEO_URL")

if [ "$VERBOSE" = "false" ]; then
    YT_DLP_SUB_DOWNLOAD_CMD+=(--quiet)
fi

if [ "$VERBOSE" = "true" ]; then
    echo "DEBUG: Executing subtitle download command: ${YT_DLP_SUB_DOWNLOAD_CMD[*]}"
fi

if ! "${YT_DLP_SUB_DOWNLOAD_CMD[@]}"; then
    echo "Error: yt-dlp failed to download subtitles."
    exit 1
fi

# Find the actual downloaded VTT file (should be one)
ACTUAL_TEMP_VTT_FILE=$(find . -maxdepth 1 -type f -name "${DOWNLOADED_SUB_PATH_PATTERN}.*.vtt" -print -quit)

if [ -z "$ACTUAL_TEMP_VTT_FILE" ] || [ ! -f "$ACTUAL_TEMP_VTT_FILE" ]; then
    echo "Error: Could not find downloaded English auto-generated transcript VTT file."
    echo "Looked for files matching: ${DOWNLOADED_SUB_PATH_PATTERN}.*.vtt in the current directory."
    ls -la . # For debugging
    exit 1
fi
echo "Subtitles downloaded to: $ACTUAL_TEMP_VTT_FILE"

# Prepare filename components
CURRENT_DATE=$(date +%Y-%m-%d)
SNAKE_CASE_CHANNEL=$(to_snake_case "$VIDEO_CHANNEL")
SNAKE_CASE_TITLE=$(to_snake_case "$VIDEO_TITLE")

# Define the output path and filename
# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILENAME="${CURRENT_DATE} transcript__${SNAKE_CASE_CHANNEL}__${SNAKE_CASE_TITLE}.md"
FINAL_OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_FILENAME}"

if [ "$VERBOSE" = "true" ]; then
    echo "DEBUG: FINAL_OUTPUT_PATH is $FINAL_OUTPUT_PATH"
fi

# Prepare frontmatter components
LOWERCASE_VIDEO_CHANNEL=$(echo "$VIDEO_CHANNEL" | tr '[:upper:]' '[:lower:]')
if [ "$VERBOSE" = "true" ]; then
    echo "DEBUG: Lowercase channel for frontmatter: $LOWERCASE_VIDEO_CHANNEL"
fi

# Write YAML frontmatter (overwrite existing file or create new)
{
    printf -- "---
"
    printf "type:
"
    printf "  - \"type/clipping\"
"
    printf "area:
"
    printf "keywords:
"
    printf "status:
"
    printf "  - \"status/unprocessed\"
"
    printf "created: %s\n" "$CURRENT_DATE"
    printf "published: %s\n" "$CURRENT_DATE"
    printf "source: %s\n" "$VIDEO_URL"
    printf "author:
"
    printf "  - \"%s\"
" "$LOWERCASE_VIDEO_CHANNEL"
    printf -- "---

" # Ensures a blank line after frontmatter
} > "$FINAL_OUTPUT_PATH"

if [ "$VERBOSE" = "true" ]; then
    echo "DEBUG: Frontmatter written. Appending cleaned transcript content..."
fi

# Clean the VTT file to extract pure text using awk
# 1. Skip header block (WEBVTT, Kind, Language, etc.)
# 2. Skip cue numbers (lines with only digits)
# 3. Skip timestamp lines (containing "-->")
# 4. Remove HTML-like tags (e.g., <c.colorFFFFFF>, <v Author>)
# 5. Trim leading/trailing whitespace from each line
# 6. Print line if not empty and not same as previous (deduplication)
awk '
    BEGIN {
        in_header = 1
        prev_line = ""
    }
    /^$/ {
        if (in_header) { in_header = 0 }
        next
    }
    in_header && (/^WEBVTT/ || /^Kind:/ || /^Language:/ || /^NOTE/ || /^STYLE/ || /^[0-9]+$/ || /-->/) { next }
    in_header { next }

    /^[0-9]+$/ { next }
    /-->/ { next }

    {
        gsub(/<[^>]*>/, "", $0)
        gsub(/^[ \t]+|[ \t]+$/, "", $0)
        if ($0 != "" && $0 != prev_line) {
            print $0
            prev_line = $0
        }
    }
' "$ACTUAL_TEMP_VTT_FILE" >> "$FINAL_OUTPUT_PATH"

# Check if the output file was created and is not empty
if [ ! -s "$FINAL_OUTPUT_PATH" ]; then
    echo "Error: Output file $FINAL_OUTPUT_PATH was not created or is empty after processing."
    echo "Temporary VTT file $ACTUAL_TEMP_VTT_FILE is kept for inspection."
    # In this error case, prevent the trap from removing the VTT file for debugging
    trap - EXIT # Disable the trap
    exit 1
else
    # Temporary VTT file will be removed by the cleanup trap on successful exit
    echo "Transcript successfully saved to: $FINAL_OUTPUT_PATH"
fi

exit 0
