#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Toggle Kanata
# @raycast.mode compact

# Optional parameters:
# @raycast.icon ●
# @raycast.packageName System

# Documentation:
# @raycast.author bdsqqq
# @raycast.authorURL https://raycast.com/bdsqqq
# @raycast.description Toggle kanata keyboard remapping on/off

# Works on both macOS (with nix-darwin) and Linux
# Compatible with Raycast and waybar

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    echo "✗ Unsupported OS: $OSTYPE"
    exit 1
fi

# Function to check if kanata is running
is_kanata_running() {
    if pgrep -x kanata > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to get current status for waybar/raycast
get_status() {
    if is_kanata_running; then
        echo "●"
    else
        echo "○"
    fi
}

# Function to start kanata
start_kanata() {
    if [[ "$OS" == "macos" ]]; then
        # Use the nix-darwin provided script
        if command -v kanata-start > /dev/null; then
            kanata-start > /dev/null 2>&1
        else
            echo "✗ kanata-start command not found. Is nix-darwin kanata module enabled?"
            exit 1
        fi
    else
        # Linux - assume systemd service
        if systemctl --user is-enabled kanata.service > /dev/null 2>&1; then
            systemctl --user start kanata.service
        else
            echo "✗ kanata.service not found or not enabled"
            exit 1
        fi
    fi
}

# Function to stop kanata
stop_kanata() {
    if [[ "$OS" == "macos" ]]; then
        # Stop launchd services using proper commands
        sudo launchctl stop com.bdsqqq.kanata 2>/dev/null || true
        sudo launchctl stop com.bdsqqq.karabiner-virtualhid-daemon 2>/dev/null || true
        
        # Bootout services to prevent restart
        sudo launchctl bootout system /Library/LaunchDaemons/com.bdsqqq.kanata.plist 2>/dev/null || true
        sudo launchctl bootout system /Library/LaunchDaemons/com.bdsqqq.karabiner-virtualhid-daemon.plist 2>/dev/null || true
        
        # Use the nix-darwin provided script as backup
        if command -v kanata-stop > /dev/null; then
            kanata-stop > /dev/null 2>&1
        fi
        
        # Final fallback to manual kill
        sudo killall kanata 2>/dev/null || true
        sudo killall Karabiner-VirtualHIDDevice-Daemon 2>/dev/null || true
    else
        # Linux - assume systemd service
        if systemctl --user is-active kanata.service > /dev/null 2>&1; then
            systemctl --user stop kanata.service
        else
            # Fallback to manual kill
            pkill kanata 2>/dev/null || true
        fi
    fi
}

# Main logic
case "${1:-toggle}" in
    "status")
        get_status
        ;;
    "on"|"start"|"enable")
        if is_kanata_running; then
            echo "● Kanata already running"
        else
            start_kanata
            sleep 3
            if is_kanata_running; then
                echo "✓ Kanata started"
            else
                echo "✗ Failed to start kanata"
                exit 1
            fi
        fi
        ;;
    "off"|"stop"|"disable")
        if is_kanata_running; then
            stop_kanata
            sleep 3
            if is_kanata_running; then
                echo "✗ Failed to stop kanata"
                exit 1
            else
                echo "✓ Kanata stopped"
            fi
        else
            echo "○ Kanata already stopped"
        fi
        ;;
    "toggle"|*)
        if is_kanata_running; then
            stop_kanata
            sleep 3
            if is_kanata_running; then
                echo "✗ Failed to stop kanata"
                exit 1
            else
                echo "✓ Kanata stopped"
            fi
        else
            start_kanata
            sleep 3
            if is_kanata_running; then
                echo "✓ Kanata started"
            else
                echo "✗ Failed to start kanata"
                exit 1
            fi
        fi
        ;;
esac
