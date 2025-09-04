#!/bin/bash
# start-with-management.sh - Container/Service Startup Script
# Initializes the complete Minecraft Server Management Platform
# Can be run from systemd service or directly

# Get script directory and source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "=== Minecraft Server Management Platform Startup ==="
echo "Script Directory: $SCRIPT_DIR"
echo "Server Directory: $SERVER_DIR"
echo "Startup Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Started by: ${SUDO_USER:-$USER} (PID: $$)"
echo ""

# Log startup
log_message "$MANAGER_LOG" "=== Platform startup initiated (PID: $$) ==="

# Function to cleanup and exit gracefully
cleanup_and_exit() {
    local exit_code=$1
    echo ""
    echo "=== Startup ${exit_code:+Failed (exit $exit_code) ===}" | tee -a "$MANAGER_LOG"
    
    # If startup failed, try to clean up any partial starts
    if [ "$exit_code" != "0" ]; then
        echo "Cleaning up partial startup..."
        for screen_session in "$SERVER_SCREEN" "$RESTART_SCREEN" "$MONITOR_SCREEN" "$BACKUP_SCREEN"; do
            if screen -list | grep -q "$screen_session"; then
                echo "Stopping partially started session: $screen_session"
                screen -S "$screen_session" -X quit 2>/dev/null
            fi
        done
    fi
    
    exit "$exit_code"
}

# Set up signal handlers for systemd
trap 'cleanup_and_exit 130' INT
trap 'cleanup_and_exit 143' TERM

# Wait for system to be fully ready (more important for systemd)
echo "Waiting for system initialization..."
sleep 5

# Check if required directories exist
echo "Checking directory structure..."
if [ ! -d "$SERVER_DIR" ]; then
    echo "WARNING: Server directory not found: $SERVER_DIR"
    echo "Please create the SERVER directory and place your Minecraft server files there"
    log_message "$MANAGER_LOG" "WARNING: Server directory not found"
    # Don't exit - let the service start anyway, user can fix this later
fi

# Verify essential scripts exist
for script in "server-manager.sh" "server-controller.sh" "config.sh"; do
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        echo "ERROR: Essential script missing: $script"
        log_message "$MANAGER_LOG" "ERROR: Essential script missing: $script"
        cleanup_and_exit 1
    fi
done

# Make all scripts executable
echo "Setting script permissions..."
chmod +x "$SCRIPT_DIR"/*.sh

# Clean up any existing screen sessions from previous runs
echo "Cleaning up old screen sessions..."
for screen_session in "$SERVER_SCREEN" "$RESTART_SCREEN" "$MONITOR_SCREEN" "$BACKUP_SCREEN"; do
    if screen -list | grep -q "$screen_session"; then
        echo "Terminating old screen session: $screen_session"
        screen -S "$screen_session" -X quit 2>/dev/null
        log_message "$MANAGER_LOG" "Cleaned up old screen session: $screen_session"
    fi
done

# Wait a moment for cleanup
sleep 2

# Start the complete server management platform
echo "Starting Minecraft Server Management Platform..."
echo ""

if "$SCRIPT_DIR/server-manager.sh" start; then
    echo ""
    echo "=== Startup Complete ==="
    echo "All components have been started successfully!"
    echo ""
    echo "Available screen sessions:"
    screen -list | grep -E "$SERVER_SCREEN|$RESTART_SCREEN|$MONITOR_SCREEN|$BACKUP_SCREEN" || echo "No sessions found (check logs)"
    echo ""
    echo "Management commands:"
    echo "  Status:       $SCRIPT_DIR/server-manager.sh status"
    echo "  Console:      screen -r $SERVER_SCREEN"
    echo "  Monitor:      screen -r $MONITOR_SCREEN"
    echo "  Auto-restart: screen -r $RESTART_SCREEN"
    echo "  Service logs: journalctl -u minecraft-server -f"
    echo "  Help:         $SCRIPT_DIR/server-manager.sh help"
    echo ""
    echo "To detach from any screen session: Ctrl+A, then D"
    
    log_message "$MANAGER_LOG" "Startup completed successfully"
    
    # For systemd compatibility - keep the process running in background
    # The screen sessions will continue even if this script exits
    if [ "${1:-}" = "--daemon" ] || [ -n "${SYSTEMD_EXEC_PID:-}" ]; then
        echo "Running in daemon mode for systemd..."
        log_message "$MANAGER_LOG" "Running in daemon mode"
        
        # Create a simple monitoring loop to keep service "active"
        while true; do
            # Check if at least the server is still running
            if ! screen_exists "$SERVER_SCREEN"; then
                echo "Server screen session lost - service should restart"
                log_message "$MANAGER_LOG" "Server screen session lost"
                cleanup_and_exit 1
            fi
            sleep 60  # Check every minute
        done
    fi
    
else
    echo ""
    echo "=== Startup Failed ==="
    echo "Some components failed to start. Check the logs for details:"
    echo "  Manager Log: $MANAGER_LOG"
    echo "  Server Log:  $SERVER_LOG"
    echo "  Service logs: journalctl -u minecraft-server"
    echo ""
    echo "You can try starting components manually:"
    echo "  $SCRIPT_DIR/server-manager.sh start"
    
    log_message "$MANAGER_LOG" "Startup failed"
    cleanup_and_exit 1
fi
