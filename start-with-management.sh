#!/bin/bash
# start-with-management.sh - LXC Container Startup Script
# Initializes the complete Minecraft Server Management Platform

# Get script directory and source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "=== Minecraft Server Management Platform Startup ==="
echo "Script Directory: $SCRIPT_DIR"
echo "Server Directory: $SERVER_DIR"
echo "Container Startup Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Log startup
log_message "$MANAGER_LOG" "=== Container startup initiated ==="

# Wait for system to be fully ready
echo "Waiting for system initialization..."
sleep 10

# Check if required directories exist
echo "Checking directory structure..."
if [ ! -d "$SERVER_DIR" ]; then
    echo "WARNING: Server directory not found: $SERVER_DIR"
    echo "Please create the SERVER directory and place your Minecraft server files there"
    log_message "$MANAGER_LOG" "WARNING: Server directory not found"
fi

# Make all scripts executable
echo "Setting script permissions..."
chmod +x "$SCRIPT_DIR"/*.sh

# Kill any existing screen sessions from previous runs
echo "Cleaning up old screen sessions..."
for screen_session in "$SERVER_SCREEN" "$RESTART_SCREEN" "$MONITOR_SCREEN" "$BACKUP_SCREEN"; do
    if screen -list | grep -q "$screen_session"; then
        echo "Terminating old screen session: $screen_session"
        screen -S "$screen_session" -X quit 2>/dev/null
        log_message "$MANAGER_LOG" "Cleaned up old screen session: $screen_session"
    fi
done

# Wait a moment for cleanup
sleep 3

# Start the complete server management platform
echo "Starting Minecraft Server Management Platform..."
echo ""

if "$SCRIPT_DIR/server-manager.sh" start; then
    echo ""
    echo "=== Startup Complete ==="
    echo "All components have been started successfully!"
    echo ""
    echo "Available screen sessions:"
    screen -list | grep -E "$SERVER_SCREEN|$RESTART_SCREEN|$MONITOR_SCREEN|$BACKUP_SCREEN" || echo "No sessions found"
    echo ""
    echo "Management commands:"
    echo "  Status:      $SCRIPT_DIR/server-manager.sh status"
    echo "  Console:     screen -r $SERVER_SCREEN"
    echo "  Monitor:     screen -r $MONITOR_SCREEN"
    echo "  Auto-restart: screen -r $RESTART_SCREEN"
    echo "  Help:        $SCRIPT_DIR/server-manager.sh help"
    echo ""
    echo "To detach from any screen session: Ctrl+A, then D"
    
    log_message "$MANAGER_LOG" "Startup completed successfully"
else
    echo ""
    echo "=== Startup Failed ==="
    echo "Some components failed to start. Check the logs for details:"
    echo "  Manager Log: $MANAGER_LOG"
    echo "  Server Log:  $SERVER_LOG"
    echo ""
    echo "You can try starting components manually:"
    echo "  $SCRIPT_DIR/server-manager.sh start"
    
    log_message "$MANAGER_LOG" "Startup failed"
    exit 1
fi
