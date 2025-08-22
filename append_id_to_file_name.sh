#!/bin/bash

# Git-aware script to add unique IDs to filenames for improved file management
# Converts: YYYY-MM-DD title -- tag1 tag2.ext
# To:       YYYY-MM-DD title -- id__<base36_id> tag1 tag2.ext
#
# Hybrid system rules:
# - Files not in git repos: always add ID if needed
# - Files in git repos: only add ID to knowledge assets (.md, .pdf, etc.), skip code assets

# Function to display usage information
usage() {
    echo "Usage: $0 [--dry-run|-n] <directory_path>"
    echo "  --dry-run, -n    Show what would be renamed without actually renaming"
    echo "  directory_path   Path to the directory containing files to process"
    exit 1
}

# Initialize variables
DRY_RUN=false
DIRECTORY=""
SCRIPT_NAME=$(basename "$0")

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        -*)
            echo "Error: Unknown option $1"
            usage
            ;;
        *)
            if [[ -z "$DIRECTORY" ]]; then
                DIRECTORY="$1"
            else
                echo "Error: Too many arguments"
                usage
            fi
            shift
            ;;
    esac
done

# Check if directory argument is provided
if [[ -z "$DIRECTORY" ]]; then
    echo "Error: Directory path is required"
    usage
fi

# Check if the provided path is a valid directory
if [[ ! -d "$DIRECTORY" ]]; then
    echo "Error: '$DIRECTORY' is not a valid directory"
    exit 1
fi

# Function to generate a unique base36 ID
generate_id() {
    echo "36o $(date +%s%N) p" | dc | tr '[:upper:]' '[:lower:]'
}

# Function to check if a file is inside a git repository
is_in_git_repo() {
    local file_path="$1"
    local dir_path=$(dirname "$file_path")
    
    # Change to the file's directory and check if it's in a git repo
    (cd "$dir_path" && git rev-parse --is-inside-work-tree >/dev/null 2>&1)
}

# Function to check if a file is a knowledge asset that should be renamed
is_knowledge_asset() {
    local filename="$1"
    local extension="${filename##*.}"
    
    # Convert to lowercase for case-insensitive comparison
    extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
    
    # List of knowledge asset extensions
    case "$extension" in
        md|pdf|png|jpg|jpeg|gif|svg|canvas|txt|rtf|docx|xlsx|pptx)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Initialize counters
files_renamed=0
files_skipped=0

# Find and process files that need IDs
while IFS= read -r -d '' file; do
    # Get the basename of the file
    basename_file=$(basename "$file")
    
    # Skip the script itself
    if [[ "$basename_file" == "$SCRIPT_NAME" ]]; then
        continue
    fi
    
    # Check if file contains '--' but not 'id__'
    if [[ "$basename_file" == *"--"* ]] && [[ "$basename_file" != *"id__"* ]]; then
        # Check if file is in a git repository
        if is_in_git_repo "$file"; then
            # File is in git repo - only rename if it's a knowledge asset
            if is_knowledge_asset "$basename_file"; then
                # It's a knowledge asset, proceed with renaming
                process_file=true
            else
                # It's a code asset, skip it
                echo "Skipping code file: '$file'"
                ((files_skipped++))
                process_file=false
            fi
        else
            # File is not in git repo - always process
            process_file=true
        fi
        
        # Process the file if we determined it should be renamed
        if [[ "$process_file" == true ]]; then
            # Generate new ID
            new_id=$(generate_id)
            
            # Split filename at the '--' separator
            before_separator="${basename_file%% --*}"
            after_separator="${basename_file#*-- }"
            
            # Construct new filename with ID inserted after '--'
            new_basename="${before_separator} -- id__${new_id} ${after_separator}"
            
            # Get the directory path
            dir_path=$(dirname "$file")
            new_file_path="${dir_path}/${new_basename}"
            
            # Display the rename operation
            echo "Renaming '$basename_file' to '$new_basename'"
            
            # Perform the rename unless in dry-run mode
            if [[ "$DRY_RUN" == false ]]; then
                if mv "$file" "$new_file_path"; then
                    ((files_renamed++))
                else
                    echo "Error: Failed to rename '$basename_file'"
                fi
            else
                ((files_renamed++))
            fi
        fi
    fi
done < <(find "$DIRECTORY" -type f -print0)

# Print summary
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run completed. Would rename $files_renamed files, skipped $files_skipped code files."
else
    echo "Completed. Renamed $files_renamed files, skipped $files_skipped code files."
fi