#!/bin/bash

# Script to save Claude Code conversations to commonplace vault
# Supports both new conversations and appending to existing ones
# Usage: ./save-claude-conversation.sh <topic> [--append] [additional-keywords]

set -e

# Configuration
COMMONPLACE_ROOT="/Users/bdsqqq/commonplace"
CLAUDE_HISTORY_DIR="$COMMONPLACE_ROOT/01_files/claude_history"

# Ensure directory exists
mkdir -p "$CLAUDE_HISTORY_DIR"
DATE=$(date +%Y-%m-%d)
CURRENT_PATH=$(pwd)

# Check required arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <topic> [--append] [additional-keywords]"
    echo "Example: $0 vector_database --append sqlite embeddings"
    echo "Example: $0 debugging"
    exit 1
fi

# Parse arguments
TOPIC="$1"
shift

APPEND_MODE=false
ADDITIONAL_KEYWORDS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --append)
            APPEND_MODE=true
            shift
            ;;
        *)
            ADDITIONAL_KEYWORDS="$ADDITIONAL_KEYWORDS $1"
            shift
            ;;
    esac
done

# Generate filename following commonplace convention
FILENAME="${DATE} ${TOPIC} -- type__conversation.md"
FILEPATH="$CLAUDE_HISTORY_DIR/$FILENAME"

# Create frontmatter for new files
create_frontmatter() {
    local frontmatter="---
type:
- type/conversation
keywords:
- keywords/claude-code
- keywords/conversation"

    # Add additional keywords if provided
    if [ -n "$ADDITIONAL_KEYWORDS" ]; then
        for keyword in $ADDITIONAL_KEYWORDS; do
            frontmatter="$frontmatter
- keywords/${keyword}"
        done
    fi

    frontmatter="$frontmatter
status:
- status/active
created: $DATE
source: claude-code
execution_path: $CURRENT_PATH
tags:
- type/conversation
permalink: ${TOPIC//_/-}
---

# $(echo "$TOPIC" | sed 's/_/ /g' | sed 's/\b\w/\u&/g')

**Execution Context:** Claude Code running from \`$CURRENT_PATH\`

"
    echo "$frontmatter"
}

# Function to get clipboard content or stdin
get_conversation_content() {
    if [ -t 0 ]; then
        # No stdin, try clipboard
        if command -v pbpaste >/dev/null 2>&1; then
            pbpaste
        elif command -v xclip >/dev/null 2>&1; then
            xclip -selection clipboard -o
        else
            echo "Error: No clipboard tool found (pbpaste/xclip) and no stdin provided"
            echo "Usage: $0 <topic> < conversation.txt"
            echo "   or: Copy conversation to clipboard and run script"
            exit 1
        fi
    else
        # Read from stdin
        cat
    fi
}

# Get conversation content
echo "Getting conversation content..."
CONVERSATION_CONTENT=$(get_conversation_content)

if [ -z "$CONVERSATION_CONTENT" ]; then
    echo "Error: No conversation content found"
    exit 1
fi

# Handle append mode vs new file
if [ "$APPEND_MODE" = true ] && [ -f "$FILEPATH" ]; then
    # Append mode: add separator and new content
    echo "" >> "$FILEPATH"
    echo "---" >> "$FILEPATH"
    echo "" >> "$FILEPATH"
    echo "## Continued - $(date '+%Y-%m-%d %H:%M') from \`$CURRENT_PATH\`" >> "$FILEPATH"
    echo "" >> "$FILEPATH"
    echo "$CONVERSATION_CONTENT" >> "$FILEPATH"
    echo "[+] Content appended to existing file: $FILENAME"
    
elif [ -f "$FILEPATH" ]; then
    # File exists but not in append mode
    echo "Error: File already exists: $FILENAME"
    echo "Use --append to add to existing conversation, or choose different topic name"
    exit 1
    
else
    # New file: create with frontmatter
    create_frontmatter > "$FILEPATH"
    echo "$CONVERSATION_CONTENT" >> "$FILEPATH"
    echo "[+] New conversation saved: $FILENAME"
fi

echo "    Path: $FILEPATH"
echo "    Executed from: $CURRENT_PATH"