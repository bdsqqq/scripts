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
COOKIES_FILE="$HOME/commonplace/01_files/cookies/instagram_cookies.txt"

# Function to sanitize text to snake_case
sanitize_filename() {
    echo "$1" | sed 's/[^a-zA-Z0-9_-]/_/g' | sed 's/__*/_/g' | sed 's/_*$//g' | tr '[:upper:]' '[:lower:]'
}

if [ -z "$URL" ]; then
    echo "Error: Please provide a URL"
    exit 1
fi

mkdir -p "$INBOX_DIR"
mkdir -p "$(dirname "$COOKIES_FILE")"

# Download with temporary filename
TEMP_OUTPUT="$INBOX_DIR/temp_$(date +%s)"

# Check if cookies file exists
COOKIE_ARGS=""
if [ -f "$COOKIES_FILE" ]; then
    COOKIE_ARGS="--cookies $COOKIES_FILE"
    echo "Using cookies from: $COOKIES_FILE"
fi

# First try with yt-dlp for video content
echo "Attempting video download with yt-dlp..."
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
    $COOKIE_ARGS \
    --output "${TEMP_OUTPUT}.%(ext)s" \
    "$URL" 2>/dev/null

# Check if video download succeeded
DOWNLOADED_FILE=$(ls "${TEMP_OUTPUT}".* 2>/dev/null | grep -v '.info.json' | head -1)

if [ -z "$DOWNLOADED_FILE" ]; then
    echo "Video download failed, trying image download with gallery-dl..."
    
    # Clean up any partial files
    rm -f "${TEMP_OUTPUT}".* 2>/dev/null
    
    # Try with gallery-dl for images
    GALLERY_COOKIE_ARGS=""
    if [ -f "$COOKIES_FILE" ]; then
        GALLERY_COOKIE_ARGS="--cookies $COOKIES_FILE"
    fi
    
    # Create timestamp before gallery-dl to detect new files
    BEFORE_GALLERY=$(date +%s)
    
    gallery-dl \
        --write-info-json \
        --directory "$INBOX_DIR" \
        --filename "${TODAY}_{category}_{subcategory}_{filename}.{extension}" \
        $GALLERY_COOKIE_ARGS \
        "$URL"
    
    # Check if gallery-dl succeeded by looking for files created after we started
    sleep 1  # Brief pause to ensure timestamp differences
    GALLERY_FILES=$(find "$INBOX_DIR" -name "${TODAY}_*" -type f -newer /tmp/gallery_timestamp_${BEFORE_GALLERY} 2>/dev/null || find "$INBOX_DIR" -name "${TODAY}_*" -type f -newermt "@$BEFORE_GALLERY" 2>/dev/null)
    
    # Alternative check: look for any files matching our pattern that didn't exist before
    if [ -z "$GALLERY_FILES" ]; then
        GALLERY_FILES=$(find "$INBOX_DIR" -name "${TODAY}_*" -type f 2>/dev/null | head -5)
    fi
    
    if [ -n "$GALLERY_FILES" ]; then
        echo "Downloaded with gallery-dl:"
        echo "$GALLERY_FILES" | while read -r file; do
            echo "  $(basename "$file")"
        done
        
        # Clean up .info.json files created by gallery-dl
        find "$INBOX_DIR" -name "${TODAY}_*.info.json" -type f -delete 2>/dev/null
        
        echo "Cleaned up metadata files"
        exit 0
    else
        echo "Gallery-dl also failed, trying yt-dlp with different options..."
        
        # Try yt-dlp again but specifically for images/posts
        yt-dlp \
            --write-info-json \
            --embed-thumbnail \
            --embed-metadata \
            --add-metadata \
            $COOKIE_ARGS \
            --output "${TEMP_OUTPUT}.%(ext)s" \
            "$URL"
        
        DOWNLOADED_FILE=$(ls "${TEMP_OUTPUT}".* 2>/dev/null | grep -v '.info.json' | head -1)
    fi
fi

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
        
        # Keep only the media file and info.json, remove everything else
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
    if [ ! -f "$COOKIES_FILE" ]; then
        echo "Error: No file was downloaded with any method"
        echo "Tip: Try adding Instagram cookies to: $COOKIES_FILE"
        echo "You can export cookies using a browser extension like 'Get cookies.txt LOCALLY'"
    else
        echo "Error: No file was downloaded even with cookies"
    fi
    exit 1
fi
