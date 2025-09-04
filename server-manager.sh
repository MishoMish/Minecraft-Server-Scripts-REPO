#!/bin/bash
# server-manager.sh - Main Minecraft Server Management Platform
# Orchestrates all server components with easy management interface

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# ================= Helper Functions =================
usage() {
    echo "Minecraft Server Management Platform"
    echo "Usage: $0 {start|stop|restart|status|monitor|backup|console|logs|help} [options]"
    echo ""
    echo "Main Commands:"
    echo "  start          - Start all server components"
    echo "  stop           - Stop all server components gracefully"
    echo "  restart        - Restart all components"
    echo "  status         - Show comprehensive status of all components"
    echo ""
    echo "Component Management:"
    echo "  server         - Manage only the Minecraft server"
    echo "  auto-restart   - Manage only the auto-restart system"
    echo "  monitoring     - Manage only the monitoring system"
    echo "  backup         - Manage backup operations"
    echo ""
    echo "Information Commands:"
    echo "  console        - Attach to server console"
    echo "  logs           - View recent logs"
    echo "  players        - Show current players"
    echo ""
    echo "Utility Commands:"
    echo "  send <cmd>     - Send command to server"
    echo "  save           - Force save world"
    echo "  cleanup        - Clean up old logs and temporary files"
    echo "  help           - Show detailed help"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start everything"
    echo "  $0 server start             # Start only the server"
    echo "  $0 send \"time set day\"      # Send command to server"
    echo "  $0 logs monitor             # View monitoring logs"
    echo ""
    exit 1
}

detailed_help() {
    echo "=== Minecraft Server Management Platform - Detailed Help ==="
    echo ""
    echo "OVERVIEW:"
    echo "This platform manages a Minecraft server with the following components:"
    echo "  - Minecraft Server (runs in screen: $SERVER_SCREEN)"
    echo "  - Auto-restart Manager (runs in screen: $RESTART_SCREEN)"
    echo "  - Performance Monitor (runs in screen: $MONITOR_SCREEN)"
    echo "  - Backup System (runs in screen: $BACKUP_SCREEN)"
    echo ""
    echo "DIRECTORY STRUCTURE:"
    echo "  Scripts: $SCRIPT_DIR"
    echo "  Server:  $SERVER_DIR"
    echo "  Logs:    $LOG_DIR"
    echo "  Backups: $BACKUP_DIR"
    echo ""
    echo "SCREEN SESSIONS:"
    echo "  View all:     screen -list"
    echo "  Attach:       screen -r <session_name>"
    echo "  Detach:       Ctrl+A, then D"
    echo ""
    echo "CONFIGURATION:"
    echo "  Edit $SCRIPT_DIR/config.sh to modify settings"
    echo ""
    echo "PROXMOX INTEGRATION:"
    echo "  Add to LXC startup: $SCRIPT_DIR/start-with-management.sh"
    echo ""
}

# Check component status
check_component_status() {
    local component="$1"
    local screen_name="$2"
    
    if screen_exists "$screen_name"; then
        echo "$component: RUNNING (screen: $screen_name)"
        return 0
    else
        echo "$component: STOPPED"
        return 1
    fi
}

# Start individual component
start_component() {
    local component="$1"
    local screen_name="$2"
    local script_path="$3"
    local args="${4:-}"
    
    if screen_exists "$screen_name"; then
        echo "$component is already running!"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        echo "Error: $component script not found or not executable: $script_path"
        return 1
    fi
    
    echo "Starting $component..."
    screen -dmS "$screen_name" bash -c "
        echo 'Starting $component...'
        echo 'Screen: $screen_name'
        echo 'Script: $script_path'
        echo 'Args: $args'
        echo '======================='
        cd '$SCRIPT_DIR'
        '$script_path' $args
        echo ''
        echo '$component has stopped. Press any key to close this screen...'
        read
    "
    
    sleep 2
    if screen_exists "$screen_name"; then
        echo "$component started successfully in screen: $screen_name"
        log_message "$MANAGER_LOG" "$component started in screen: $screen_name"
        return 0
    else
        echo "Failed to start $component!"
        log_message "$MANAGER_LOG" "Failed to start $component"
        return 1
    fi
}

# Stop individual component
stop_component() {
    local component="$1"
    local screen_name="$2"
    local graceful_command="$3"
    
    if ! screen_exists "$screen_name"; then
        echo "$component is not running!"
        return 1
    fi
    
    echo "Stopping $component..."
    
    if [ -n "$graceful_command" ]; then
        echo "Sending graceful stop command..."
        screen -S "$screen_name" -X stuff "$graceful_command$(printf \\r)"
        sleep 5
    fi
    
    # Force quit the screen session
    screen -S "$screen_name" -X quit
    sleep 2
    
    if ! screen_exists "$screen_name"; then
        echo "$component stopped successfully"
        log_message "$MANAGER_LOG" "$component stopped"
        return 0
    else
        echo "Failed to stop $component gracefully, force killing..."
        screen -S "$screen_name" -X kill
        sleep 1
        if ! screen_exists "$screen_name"; then
            echo "$component force stopped"
            log_message "$MANAGER_LOG" "$component force stopped"
            return 0
        else
            echo "Failed to stop $component!"
            log_message "$MANAGER_LOG" "Failed to stop $component"
            return 1
        fi
    fi
}

# Start all components
start_all() {
    echo "=== Starting Minecraft Server Management Platform ==="
    log_message "$MANAGER_LOG" "Starting all components"
    
    local success=0
    
    # Start server first - call server-controller directly (it creates its own screen)
    echo "Starting Minecraft Server..."
    if "$SCRIPT_DIR/server-controller.sh" start; then
        echo "Minecraft Server started successfully"
        log_message "$MANAGER_LOG" "Minecraft Server started"
        ((success++))
    else
        echo "Failed to start Minecraft Server!"
        log_message "$MANAGER_LOG" "Failed to start Minecraft Server"
    fi
    
    sleep 5
    
    # Start auto-restart manager
    start_component "Auto-restart Manager" "$RESTART_SCREEN" "$SCRIPT_DIR/mc-auto-restart.sh"
    [ $? -eq 0 ] && ((success++))
    
    # Start monitoring
    start_component "Performance Monitor" "$MONITOR_SCREEN" "$SCRIPT_DIR/monitor.sh" "start"
    [ $? -eq 0 ] && ((success++))
    
    # Start backup system if script exists
    if [ -x "$SCRIPT_DIR/backup.sh" ]; then
        start_component "Backup System" "$BACKUP_SCREEN" "$SCRIPT_DIR/backup.sh" "start"
        [ $? -eq 0 ] && ((success++))
    fi
    
    echo ""
    echo "Started $success components successfully!"
    echo "Use 'screen -list' to see all running sessions"
    echo "Use '$0 status' to check detailed status"
}

# Stop all components
stop_all() {
    echo "=== Stopping Minecraft Server Management Platform ==="
    log_message "$MANAGER_LOG" "Stopping all components"
    
    # Stop in reverse order for graceful shutdown
    
    # Stop backup system
    if screen_exists "$BACKUP_SCREEN"; then
        stop_component "Backup System" "$BACKUP_SCREEN"
    fi
    
    # Stop monitoring
    if screen_exists "$MONITOR_SCREEN"; then
        stop_component "Performance Monitor" "$MONITOR_SCREEN"
    fi
    
    # Stop auto-restart
    if screen_exists "$RESTART_SCREEN"; then
        stop_component "Auto-restart Manager" "$RESTART_SCREEN"
    fi
    
    # Stop server last
    if screen_exists "$SERVER_SCREEN"; then
        echo "Stopping Minecraft Server gracefully..."
        "$SCRIPT_DIR/server-controller.sh" stop
    fi
    
    echo ""
    echo "All components stopped!"
}

# Show comprehensive status
show_status() {
    echo "=== Minecraft Server Management Platform Status ==="
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    echo "=== Component Status ==="
    check_component_status "Minecraft Server" "$SERVER_SCREEN"
    check_component_status "Auto-restart Manager" "$RESTART_SCREEN"
    check_component_status "Performance Monitor" "$MONITOR_SCREEN"
    check_component_status "Backup System" "$BACKUP_SCREEN"
    
    echo ""
    echo "=== Server Details ==="
    "$SCRIPT_DIR/server-controller.sh" status
    
    echo ""
    echo "=== Recent Activity ==="
    if [ -f "$MANAGER_LOG" ]; then
        echo "Manager Log (last 5 entries):"
        tail -n 5 "$MANAGER_LOG" | sed 's/^/  /'
    fi
    
    echo ""
    echo "=== Screen Sessions ==="
    screen -list | grep -E "$SERVER_SCREEN|$RESTART_SCREEN|$MONITOR_SCREEN|$BACKUP_SCREEN" || echo "No management screen sessions found"
    
    echo ""
    echo "=== Quick Commands ==="
    echo "  Attach to server console:  screen -r $SERVER_SCREEN"
    echo "  View monitoring:           screen -r $MONITOR_SCREEN"
    echo "  View auto-restart:         screen -r $RESTART_SCREEN"
    echo "  Detach from screen:        Ctrl+A, then D"
}

# View logs
view_logs() {
    local log_type="$1"
    local lines="${2:-20}"
    
    case "$log_type" in
        server)
            if [ -f "$SERVER_LOG" ]; then
                echo "=== Server Log (last $lines lines) ==="
                tail -n "$lines" "$SERVER_LOG"
            else
                echo "Server log not found: $SERVER_LOG"
            fi
            ;;
        restart)
            if [ -f "$RESTART_LOG" ]; then
                echo "=== Restart Log (last $lines lines) ==="
                tail -n "$lines" "$RESTART_LOG"
            else
                echo "Restart log not found: $RESTART_LOG"
            fi
            ;;
        monitor)
            if [ -f "$MONITOR_LOG" ]; then
                echo "=== Monitor Log (last $lines lines) ==="
                tail -n "$lines" "$MONITOR_LOG"
            else
                echo "Monitor log not found: $MONITOR_LOG"
            fi
            ;;
        manager)
            if [ -f "$MANAGER_LOG" ]; then
                echo "=== Manager Log (last $lines lines) ==="
                tail -n "$lines" "$MANAGER_LOG"
            else
                echo "Manager log not found: $MANAGER_LOG"
            fi
            ;;
        all)
            view_logs server "$lines"
            echo ""
            view_logs restart "$lines"
            echo ""
            view_logs monitor "$lines"
            echo ""
            view_logs manager "$lines"
            ;;
        *)
            echo "Available log types: server, restart, monitor, manager, all"
            echo "Usage: $0 logs <type> [lines]"
            ;;
    esac
}

# Clean up old files
cleanup() {
    echo "=== Cleaning up old files ==="
    
    local cleaned=0
    
    # Clean up old logs (keep last 10 files of each type)
    for log_pattern in "$LOG_DIR"/*.log "$LOG_DIR"/*.csv; do
        if [ -f "$log_pattern" ]; then
            find "$(dirname "$log_pattern")" -name "$(basename "$log_pattern")" -type f | head -n -10 | xargs -r rm -f
            ((cleaned++))
        fi
    done
    
    # Clean up temporary files
    rm -f /tmp/mc_screen_dump.txt 2>/dev/null && ((cleaned++))
    
    # Clean up old backup files (keep last N backups as configured)
    if [ -d "$BACKUP_DIR" ] && [ "$BACKUP_RETENTION" -gt 0 ]; then
        find "$BACKUP_DIR" -name "*.tar.gz" -type f | sort -r | tail -n +$((BACKUP_RETENTION + 1)) | xargs -r rm -f
        ((cleaned++))
    fi
    
    echo "Cleanup completed! ($cleaned items processed)"
    log_message "$MANAGER_LOG" "Cleanup completed"
}

# ================= Main Script Logic =================
if [ $# -eq 0 ]; then
    usage
fi

case "$1" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    restart)
        echo "Restarting all components..."
        stop_all
        sleep 5
        start_all
        ;;
    status)
        show_status
        ;;
    server)
        shift
        "$SCRIPT_DIR/server-controller.sh" "$@"
        ;;
    auto-restart)
        case "$2" in
            start)
                start_component "Auto-restart Manager" "$RESTART_SCREEN" "$SCRIPT_DIR/mc-auto-restart.sh"
                ;;
            stop)
                stop_component "Auto-restart Manager" "$RESTART_SCREEN"
                ;;
            status)
                check_component_status "Auto-restart Manager" "$RESTART_SCREEN"
                ;;
            *)
                echo "Usage: $0 auto-restart {start|stop|status}"
                ;;
        esac
        ;;
    monitoring)
        case "$2" in
            start)
                start_component "Performance Monitor" "$MONITOR_SCREEN" "$SCRIPT_DIR/monitor.sh" "start"
                ;;
            stop)
                stop_component "Performance Monitor" "$MONITOR_SCREEN"
                ;;
            status)
                check_component_status "Performance Monitor" "$MONITOR_SCREEN"
                ;;
            report)
                "$SCRIPT_DIR/monitor.sh" report
                ;;
            *)
                echo "Usage: $0 monitoring {start|stop|status|report}"
                ;;
        esac
        ;;
    console)
        if screen_exists "$SERVER_SCREEN"; then
            echo "Attaching to server console (Ctrl+A, D to detach)..."
            screen -r "$SERVER_SCREEN"
        else
            echo "Server is not running!"
        fi
        ;;
    logs)
        view_logs "${2:-all}" "${3:-20}"
        ;;
    players)
        "$SCRIPT_DIR/server-controller.sh" players
        ;;
    send)
        if [ -z "$2" ]; then
            echo "Usage: $0 send <command>"
            exit 1
        fi
        "$SCRIPT_DIR/server-controller.sh" send "$2"
        ;;
    save)
        "$SCRIPT_DIR/server-controller.sh" save
        ;;
    backup)
        if [ -x "$SCRIPT_DIR/backup.sh" ]; then
            shift
            "$SCRIPT_DIR/backup.sh" "$@"
        else
            echo "Backup script not found or not executable"
        fi
        ;;
    cleanup)
        cleanup
        ;;
    help)
        detailed_help
        ;;
    *)
        echo "Unknown command: $1"
        usage
        ;;
esac
