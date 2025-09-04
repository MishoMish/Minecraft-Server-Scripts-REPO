#!/bin/bash
# debug-termination.sh - Debug why screen sessions terminate every 4 minutes

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

DEBUG_LOG="$LOG_DIR/termination_debug.log"
mkdir -p "$LOG_DIR"

echo "=== Screen Termination Debug Tool ==="
echo "This will monitor screen sessions and log what happens when they terminate"
echo "Debug log: $DEBUG_LOG"
echo

log_debug() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$DEBUG_LOG"
}

# Function to get detailed system info
get_system_info() {
    log_debug "=== SYSTEM INFO ==="
    log_debug "Memory usage: $(free -h | grep Mem:)"
    log_debug "Disk usage: $(df -h $SERVER_DIR | tail -1)"
    log_debug "Load average: $(uptime)"
    log_debug "Java processes: $(pgrep -af java | wc -l)"
    log_debug "Screen sessions: $(screen -list 2>/dev/null | grep -c "Socket")"
    
    # Check for Java process details
    if pgrep -f "$JAR_NAME" > /dev/null; then
        local pid=$(pgrep -f "$JAR_NAME")
        log_debug "Java PID: $pid"
        log_debug "Java memory: $(ps -p $pid -o pid,pcpu,pmem,rss --no-headers)"
        log_debug "Java command: $(ps -p $pid -o args --no-headers)"
    else
        log_debug "No Java process found for $JAR_NAME"
    fi
    
    # Check auto-restart status
    if screen_exists "$RESTART_SCREEN"; then
        log_debug "Auto-restart screen exists"
    else
        log_debug "Auto-restart screen NOT found"
    fi
    
    log_debug "=========================="
}

# Function to monitor a specific process
monitor_process() {
    local process_name="$1"
    local screen_name="$2"
    local start_time=$(date +%s)
    
    log_debug "Starting monitoring of $process_name (screen: $screen_name)"
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        
        # Check if screen exists
        if screen_exists "$screen_name"; then
            # Check if Java process exists
            if pgrep -f "$JAR_NAME" > /dev/null; then
                log_debug "[$minutes:$(printf "%02d" $seconds)] Screen: ✓ Java: ✓"
            else
                log_debug "[$minutes:$(printf "%02d" $seconds)] Screen: ✓ Java: ✗ (JAVA PROCESS DIED!)"
                get_system_info
                log_debug "Java process died after $minutes minutes $seconds seconds"
                break
            fi
        else
            log_debug "[$minutes:$(printf "%02d" $seconds)] Screen: ✗ (SCREEN TERMINATED!)"
            get_system_info
            log_debug "Screen session terminated after $minutes minutes $seconds seconds"
            
            # Check if Java is still running without screen
            if pgrep -f "$JAR_NAME" > /dev/null; then
                log_debug "WARNING: Java process still running without screen!"
            fi
            break
        fi
        
        # Log every 30 seconds, but check every 5 seconds
        if [ $((elapsed % 30)) -eq 0 ]; then
            log_debug "[$minutes:$(printf "%02d" $seconds)] Monitoring... (Screen: ✓ Java: ✓)"
        fi
        
        sleep 5
    done
}

# Start monitoring
log_debug "=== TERMINATION DEBUG SESSION STARTED ==="
get_system_info

# Check current status
if screen_exists "$SERVER_SCREEN"; then
    log_debug "Found existing server screen session, monitoring it..."
    monitor_process "Minecraft Server" "$SERVER_SCREEN"
else
    log_debug "No server screen session found. Starting server and monitoring..."
    
    # Kill any orphaned Java processes
    if pgrep -f "$JAR_NAME" > /dev/null; then
        log_debug "Killing orphaned Java process..."
        pkill -f "$JAR_NAME"
        sleep 5
    fi
    
    # Start server
    log_debug "Starting server with debug monitoring..."
    if "$SCRIPT_DIR/server-controller.sh" start; then
        log_debug "Server started, beginning monitoring..."
        sleep 5
        monitor_process "Minecraft Server" "$SERVER_SCREEN"
    else
        log_debug "Failed to start server!"
        exit 1
    fi
fi

log_debug "=== MONITORING ENDED ==="
echo
echo "Debug session completed. Check the log for details:"
echo "  $DEBUG_LOG"
echo
echo "Recent log entries:"
tail -20 "$DEBUG_LOG"
