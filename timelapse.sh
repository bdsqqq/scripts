#!/bin/bash

# Set the directory where the timelapse images will be stored
BASE_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/01_files/work_timelapses"

# Get the current date and time in a Finder-friendly ISO 8601-like format (replacing colons with dots)
START_DATETIME=$(date +"%Y-%m-%dT%H.%M.%SZ")

# Set the interval and duration
INTERVAL=5  # Interval in seconds
TOTAL_FRAMES=14400 # Maximum number of frames to capture

# Calculate estimated end time in the Finder-friendly format
END_DATETIME=$(date -v+${INTERVAL}S -v+${TOTAL_FRAMES}S +"%Y-%m-%dT%H.%M.%SZ")

# Create a single directory with all information in the name using the modified ISO 8601 format for time range
# Format: YYYY-MM-DDTHH.MM.SSZ-YYYY-MM-DDTHH.MM.SSZ -- type_timelapse area__work interval_Xs frames_N
DIR_NAME="${START_DATETIME}-${END_DATETIME} -- type_project__wip area__work keyword_timelapse interval_${INTERVAL}s frames_${TOTAL_FRAMES}"
TIMELAPSE_DIR="$BASE_DIR/$DIR_NAME"
mkdir -p "$TIMELAPSE_DIR"

echo "Starting timelapse, capturing every $INTERVAL seconds. Press [CTRL+C] to stop."
echo "Images will be saved to:"
echo "$TIMELAPSE_DIR"

# Change to the target directory
cd "$TIMELAPSE_DIR"

# Counter for frame number
frame=1

# Use a loop instead of imagesnap's timelapse mode
while [ $frame -le $TOTAL_FRAMES ]; do
    # Format the frame number with leading zeros
    frame_padded=$(printf "%05d" $frame)
    
    # Capture a single image
    imagesnap "snapshot-$frame_padded.jpg"
    
    echo "Captured frame $frame of $TOTAL_FRAMES"
    
    # Increment the frame counter
    ((frame++))
    
    # Wait for the specified interval
    sleep $INTERVAL
done

# Get actual end time in the Finder-friendly format
ACTUAL_END_DATETIME=$(date +"%Y-%m-%dT%H.%M.%SZ")

# Rename the directory with the actual end time and frame count
ACTUAL_DIR_NAME="${START_DATETIME}-${ACTUAL_END_DATETIME} -- type_project__done area__work keyword_timelapse interval_${INTERVAL}s frames_${frame}"
ACTUAL_TIMELAPSE_DIR="$BASE_DIR/$ACTUAL_DIR_NAME"

# Only rename if we're not at the original directory (in case of early termination)
if [ "$TIMELAPSE_DIR" != "$ACTUAL_TIMELAPSE_DIR" ]; then
    cd ..
    mv "$DIR_NAME" "$ACTUAL_DIR_NAME"
    TIMELAPSE_DIR="$ACTUAL_TIMELAPSE_DIR"
fi

echo "Timelapse completed. Images saved to:"
echo "$TIMELAPSE_DIR"
