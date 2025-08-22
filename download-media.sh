#!/bin/bash -l

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title download media
# @raycast.mode compact

# Optional parameters:
# @raycast.icon ↴
# @raycast.argument1 { "type": "text", "placeholder": "URL" }
# @raycast.packageName media_utils

# Documentation:
# @raycast.description Download media from most sites with just a URL
# @raycast.author bdsqqq
# @raycast.authorURL https://raycast.com/bdsqqq

URL="$1"
INBOX_DIR="$HOME/commonplace/00_inbox"
TODAY=$(date +%Y-%m-%d)

# Function to sanitize text to snake_case
sanitize_filename() {
    echo "$1" | sed 's/[^a-zA-Z0-9_-]/_/g' | sed 's/__*/_/g' | sed 's/_*$//g' | tr '[:upper:]' '[:lower:]'
}

if [ -z "$URL" ]; then
    echo "Error: Please provide a URL"
    exit 1
fi

mkdir -p "$INBOX_DIR"

# Download with temporary filename
TEMP_OUTPUT="$INBOX_DIR/temp_$(date +%s)"

yt-dlp \
    --format "bestvideo[height<=1080]+bestaudio/best[height<=1080]" \
    --write-info-json \
    --write-subs \
    --write-auto-subs \
    --sub-langs "en,en-US" \
    --embed-subs \
    --embed-thumbnail \
    --embed-metadata \
    --add-metadata \
    --merge-output-format "webm" \
    --output "${TEMP_OUTPUT}.%(ext)s" \
    "$URL"

# Get the actual downloaded file
DOWNLOADED_FILE=$(ls "${TEMP_OUTPUT}".* 2>/dev/null | grep -v '.info.json' | head -1)

if [ -n "$DOWNLOADED_FILE" ]; then
    # Extract metadata from info.json
    INFO_FILE="${TEMP_OUTPUT}.info.json"
    if [ -f "$INFO_FILE" ]; then
        UPLOADER=$(jq -r '.uploader // .channel // "unknown"' "$INFO_FILE")
        TITLE=$(jq -r '.title // "untitled"' "$INFO_FILE")
        EXTRACTOR=$(jq -r '.extractor_key // .extractor // "unknown"' "$INFO_FILE")
        UPLOAD_DATE=$(jq -r '.upload_date // "unknown"' "$INFO_FILE" | sed 's/^\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)$/\1-\2-\3/')
        
        # Sanitize filename components
        UPLOADER_CLEAN=$(sanitize_filename "$UPLOADER")
        TITLE_CLEAN=$(sanitize_filename "$TITLE")
        EXTRACTOR_CLEAN=$(sanitize_filename "$EXTRACTOR")
        
        # Get file extension
        EXT="${DOWNLOADED_FILE##*.}"
        
        # Create final filename
        FINAL_NAME="${TODAY} ${UPLOADER_CLEAN}-${TITLE_CLEAN}-${EXTRACTOR_CLEAN} -- type__clipping published__${UPLOAD_DATE}.${EXT}"
        
        # Move to final location
        mv "$DOWNLOADED_FILE" "$INBOX_DIR/$FINAL_NAME"
        
        # Keep only the video file and info.json, remove everything else
        INFO_FINAL="${TODAY} ${UPLOADER_CLEAN}-${TITLE_CLEAN}-${EXTRACTOR_CLEAN} -- type__clipping published__${UPLOAD_DATE}.info.json"
        mv "$INFO_FILE" "$INBOX_DIR/$INFO_FINAL"
        
        echo "Downloaded: $FINAL_NAME"
    else
        echo "Warning: No info.json file found"
        mv "$DOWNLOADED_FILE" "$INBOX_DIR/"
    fi
    
    # Clean up any remaining temp files
    rm -f "${TEMP_OUTPUT}".* 2>/dev/null
else
    echo "Error: No file was downloaded"
    exit 1
fi

