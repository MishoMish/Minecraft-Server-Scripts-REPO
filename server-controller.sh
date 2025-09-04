#!/bin/bash
# server-controller.sh - Advanced Minecraft Server Controller
# Handles start, stop, restart, and status operations with proper error handling

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# ================= Helper Functions =================
usage() {
    echo "Minecraft Server Controller"
    echo "Usage: $0 {start|stop|restart|status|force-stop|send|players|save}"
    echo ""
    echo "Commands:"
    echo "  start      - Start the Minecraft server"
    echo "  stop       - Gracefully stop the server (with 30s timeout)"
    echo "  force-stop - Force kill the server immediately"
    echo "  restart    - Restart the server (stop + start)"
    echo "  status     - Show server status and resource usage"
    echo "  send <cmd> - Send a command to the server console"
    echo "  players    - Show current players online"
    echo "  save       - Force save the world"
    echo ""
    exit 1
}

# Check if server process is running
is_server_running() {
    if screen_exists "$SERVER_SCREEN"; then
        # Additional check: see if Java process is actually running
        if pgrep -f "$JAR_NAME" > /dev/null; then
            return 0
        else
            # Screen exists but no Java process - clean up orphaned screen
            log_message "$MANAGER_LOG" "Cleaning up orphaned screen session"
            screen -S "$SERVER_SCREEN" -X quit 2>/dev/null
            return 1
        fi
    else
        return 1
    fi
}

# Wait for server to fully start
wait_for_server_start() {
    local timeout=180  # 3 minutes timeout (increased from 2 minutes)
    local count=0
    
    log_message "$SERVER_LOG" "Waiting for server to start..."
    echo "Waiting for server to start (this may take a few minutes)..."
    
    # First, wait for screen session to exist
    while [ $count -lt 30 ]; do
        if screen_exists "$SERVER_SCREEN"; then
            log_message "$SERVER_LOG" "Screen session created"
            break
        fi
        sleep 1
        ((count++))
    done
    
    if [ $count -ge 30 ]; then
        log_message "$SERVER_LOG" "Screen session creation timeout"
        return 1
    fi
    
    # Reset counter for server startup check
    count=0
    
    # Wait for Java process to start
    while [ $count -lt $timeout ]; do
        if pgrep -f "$JAR_NAME" > /dev/null; then
            log_message "$SERVER_LOG" "Java process detected"
            
            # Give server additional time to fully initialize
            echo "Server process started, waiting for full initialization..."
            sleep 10
            
            # Check if server is still running (not crashed)
            if pgrep -f "$JAR_NAME" > /dev/null; then
                log_message "$SERVER_LOG" "Server started successfully"
                echo "Server started successfully!"
                return 0
            else
                log_message "$SERVER_LOG" "Server process crashed during startup"
                return 1
            fi
        fi
        
        # Show progress every 10 seconds
        if [ $((count % 10)) -eq 0 ] && [ $count -gt 0 ]; then
            echo "Still waiting for server startup... ($count/$timeout seconds)"
        fi
        
        sleep 1
        ((count++))
    done
    
    log_message "$SERVER_LOG" "Server start timeout reached"
    echo "Server startup timeout reached!"
    return 1
}

# Wait for server to fully stop
wait_for_server_stop() {
    local timeout=30
    local count=0
    
    log_message "$SERVER_LOG" "Waiting for server to stop..."
    
    while [ $count -lt $timeout ]; do
        if ! is_server_running; then
            log_message "$SERVER_LOG" "Server stopped successfully"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    log_message "$SERVER_LOG" "Server stop timeout reached"
    return 1
}

# Start the Minecraft server
start_server() {
    if is_server_running; then
        echo "Server is already running!"
        return 1
    fi
    
    # Check if server directory exists
    if [ ! -d "$SERVER_DIR" ]; then
        echo "Error: Server directory '$SERVER_DIR' not found!"
        log_message "$SERVER_LOG" "Error: Server directory not found"
        return 1
    fi
    
    # Check if jar file exists
    if [ ! -f "$SERVER_DIR/$JAR_NAME" ]; then
        echo "Error: Server jar '$SERVER_DIR/$JAR_NAME' not found!"
        log_message "$SERVER_LOG" "Error: Server jar not found"
        return 1
    fi
    
    log_message "$SERVER_LOG" "Starting Minecraft server..."
    echo "Starting Minecraft server..."
    
    # Start server in screen session
    cd "$SERVER_DIR" || return 1
    screen -dmS "$SERVER_SCREEN" bash -c "
        echo 'Starting Minecraft Server...'
        echo 'Server Directory: $SERVER_DIR'
        echo 'JAR File: $JAR_NAME'
        echo 'RAM: $MIN_RAM to $MAX_RAM'
        echo '=========================='
        java -Xms$MIN_RAM -Xmx$MAX_RAM $JAVA_OPTS -jar '$JAR_NAME' nogui
        echo 'Server process ended. Press any key to close this screen...'
        read
    "
    
    # Wait for server to start
    if wait_for_server_start; then
        echo "Server started successfully!"
        log_message "$SERVER_LOG" "Server started in screen session: $SERVER_SCREEN"
        return 0
    else
        echo "Server failed to start properly!"
        log_message "$SERVER_LOG" "Server failed to start"
        return 1
    fi
}

# Stop the Minecraft server gracefully
stop_server() {
    if ! is_server_running; then
        echo "Server is not running!"
        return 1
    fi
    
    log_message "$SERVER_LOG" "Stopping Minecraft server gracefully..."
    echo "Stopping Minecraft server..."
    
    # Send save command first
    send_server_command "say Server is shutting down..."
    sleep 2
    send_server_command "save-all"
    sleep 3
    send_server_command "stop"
    
    # Wait for graceful shutdown
    if wait_for_server_stop; then
        echo "Server stopped successfully!"
        return 0
    else
        echo "Server didn't stop gracefully, forcing shutdown..."
        force_stop_server
        return $?
    fi
}

# Force stop the server
force_stop_server() {
    log_message "$SERVER_LOG" "Force stopping Minecraft server..."
    echo "Force stopping server..."
    
    # Kill screen session
    if screen_exists "$SERVER_SCREEN"; then
        screen -S "$SERVER_SCREEN" -X quit
    fi
    
    # Kill any remaining Java processes
    pkill -f "$JAR_NAME" 2>/dev/null
    
    sleep 2
    
    if ! is_server_running; then
        echo "Server force stopped successfully!"
        log_message "$SERVER_LOG" "Server force stopped"
        return 0
    else
        echo "Failed to stop server!"
        log_message "$SERVER_LOG" "Failed to force stop server"
        return 1
    fi
}

# Restart the server
restart_server() {
    echo "Restarting Minecraft server..."
    log_message "$SERVER_LOG" "Restarting server..."
    
    if is_server_running; then
        stop_server
        sleep 5
    fi
    
    start_server
}

# Show server status
show_status() {
    echo "=== Minecraft Server Status ==="
    
    if is_server_running; then
        echo "Status: RUNNING"
        echo "Screen Session: $SERVER_SCREEN"
        
        # Get process info
        local pid=$(pgrep -f "$JAR_NAME")
        if [ -n "$pid" ]; then
            echo "Process ID: $pid"
            
            # Memory usage
            local mem_info=$(ps -p "$pid" -o pid,pcpu,pmem,rss --no-headers)
            if [ -n "$mem_info" ]; then
                local cpu_usage=$(echo "$mem_info" | awk '{print $2}')
                local mem_percent=$(echo "$mem_info" | awk '{print $3}')
                local mem_kb=$(echo "$mem_info" | awk '{print $4}')
                local mem_mb=$((mem_kb / 1024))
                
                echo "CPU Usage: ${cpu_usage}%"
                echo "Memory Usage: ${mem_percent}% (${mem_mb}MB)"
            fi
        fi
        
        # Check if we can get player count
        if screen_exists "$SERVER_SCREEN"; then
            echo "Screen session active - use 'screen -r $SERVER_SCREEN' to attach"
        fi
        
    else
        echo "Status: STOPPED"
    fi
    
    echo ""
    echo "=== Server Directory Info ==="
    echo "Server Dir: $SERVER_DIR"
    if [ -d "$SERVER_DIR" ]; then
        echo "JAR File: $([ -f "$SERVER_DIR/$JAR_NAME" ] && echo "Found" || echo "NOT FOUND")"
        local disk_usage=$(du -sh "$SERVER_DIR" 2>/dev/null | cut -f1)
        echo "Disk Usage: ${disk_usage:-"Unknown"}"
    else
        echo "Server directory does not exist!"
    fi
    
    echo ""
    echo "=== Recent Log Activity ==="
    if [ -f "$SERVER_LOG" ]; then
        tail -n 5 "$SERVER_LOG"
    else
        echo "No log file found"
    fi
}

# Send command to server
send_command() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        echo "Error: No command specified"
        return 1
    fi
    
    if ! is_server_running; then
        echo "Error: Server is not running"
        return 1
    fi
    
    echo "Sending command to server: $cmd"
    send_server_command "$cmd"
    log_message "$SERVER_LOG" "Command sent: $cmd"
}

# Get current players
get_players() {
    if ! is_server_running; then
        echo "Server is not running"
        return 1
    fi
    
    echo "Getting player list..."
    send_server_command "list"
    echo "Check the server console for player list output"
}

# Force save world
save_world() {
    if ! is_server_running; then
        echo "Server is not running"
        return 1
    fi
    
    echo "Forcing world save..."
    send_server_command "save-all"
    log_message "$SERVER_LOG" "Manual save triggered"
}

# ================= Main Script Logic =================
if [ $# -eq 0 ]; then
    usage
fi

case "$1" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    force-stop)
        force_stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        show_status
        ;;
    send)
        if [ -z "$2" ]; then
            echo "Error: Command required for 'send' operation"
            echo "Usage: $0 send <command>"
            exit 1
        fi
        send_command "$2"
        ;;
    players)
        get_players
        ;;
    save)
        save_world
        ;;
    *)
        echo "Unknown command: $1"
        usage
        ;;
esac
