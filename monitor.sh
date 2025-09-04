#!/bin/bash
# monitor.sh - Minecraft Server Monitoring System
# Tracks server health, performance, and player activity

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# ================= Monitoring Functions =================

# Get server performance metrics
get_server_metrics() {
    local metrics=""
    
    # Check if server is running
    if ! screen_exists "$SERVER_SCREEN"; then
        echo "status=stopped"
        return 0
    fi
    
    # Get Java process info
    local pid=$(pgrep -f "$JAR_NAME")
    if [ -z "$pid" ]; then
        echo "status=stopped"
        return 0
    fi
    
    # Get process statistics
    local ps_info=$(ps -p "$pid" -o pid,pcpu,pmem,rss,etime --no-headers 2>/dev/null)
    if [ -z "$ps_info" ]; then
        echo "status=stopped"
        return 0
    fi
    
    local cpu_usage=$(echo "$ps_info" | awk '{print $2}')
    local mem_percent=$(echo "$ps_info" | awk '{print $3}')
    local mem_kb=$(echo "$ps_info" | awk '{print $4}')
    local uptime=$(echo "$ps_info" | awk '{print $5}')
    local mem_mb=$((mem_kb / 1024))
    
    # Get system metrics
    local total_mem=$(free -m | awk 'NR==2{print $2}')
    local used_mem=$(free -m | awk 'NR==2{print $3}')
    local free_mem=$(free -m | awk 'NR==2{print $4}')
    local mem_usage_percent=$((used_mem * 100 / total_mem))
    
    # Get disk usage for server directory
    local disk_usage=$(df -h "$SERVER_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    local disk_free=$(df -BG "$SERVER_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    # Get load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    # Get network connections (approximate player count from connections to server port)
    local connections=$(netstat -an 2>/dev/null | grep ":$SERVER_PORT " | grep ESTABLISHED | wc -l)
    
    echo "status=running"
    echo "pid=$pid"
    echo "cpu_usage=$cpu_usage"
    echo "mem_percent=$mem_percent"
    echo "mem_mb=$mem_mb"
    echo "uptime=$uptime"
    echo "system_mem_total=$total_mem"
    echo "system_mem_used=$used_mem"
    echo "system_mem_free=$free_mem"
    echo "system_mem_percent=$mem_usage_percent"
    echo "disk_usage_percent=$disk_usage"
    echo "disk_free_gb=$disk_free"
    echo "load_avg=$load_avg"
    echo "connections=$connections"
}

# Check for performance alerts
check_alerts() {
    local metrics="$1"
    local alerts=""
    
    # Parse metrics
    local cpu_usage=$(echo "$metrics" | grep "cpu_usage=" | cut -d'=' -f2)
    local mem_percent=$(echo "$metrics" | grep "mem_percent=" | cut -d'=' -f2)
    local disk_usage=$(echo "$metrics" | grep "disk_usage_percent=" | cut -d'=' -f2)
    local disk_free=$(echo "$metrics" | grep "disk_free_gb=" | cut -d'=' -f2)
    local system_mem_percent=$(echo "$metrics" | grep "system_mem_percent=" | cut -d'=' -f2)
    
    # Check CPU usage
    if [ -n "$cpu_usage" ] && (( $(echo "$cpu_usage > $MAX_CPU_PERCENT" | bc -l) )); then
        alerts="${alerts}HIGH_CPU($cpu_usage%) "
    fi
    
    # Check memory usage
    if [ -n "$mem_percent" ] && (( $(echo "$mem_percent > $MAX_MEMORY_PERCENT" | bc -l) )); then
        alerts="${alerts}HIGH_MEMORY($mem_percent%) "
    fi
    
    # Check system memory
    if [ -n "$system_mem_percent" ] && [ "$system_mem_percent" -gt "$MAX_MEMORY_PERCENT" ]; then
        alerts="${alerts}HIGH_SYSTEM_MEMORY($system_mem_percent%) "
    fi
    
    # Check disk space
    if [ -n "$disk_free" ] && [ "$disk_free" -lt "$MIN_FREE_DISK_GB" ]; then
        alerts="${alerts}LOW_DISK_SPACE(${disk_free}GB) "
    fi
    
    if [ -n "$alerts" ]; then
        echo "ALERTS: $alerts"
        log_message "$MONITOR_LOG" "PERFORMANCE ALERTS: $alerts"
        
        # Send alert to server if running
        if screen_exists "$SERVER_SCREEN"; then
            send_server_command "say [ALERT] Server performance issue detected!"
        fi
    fi
}

# Get recent server activity from logs
get_server_activity() {
    if [ ! -d "$SERVER_DIR/logs" ]; then
        echo "No server logs directory found"
        return
    fi
    
    local latest_log=$(find "$SERVER_DIR/logs" -name "*.log" -type f -printf '%T@ %p\n' | sort -k 1nr | head -1 | cut -d' ' -f2-)
    
    if [ -z "$latest_log" ] || [ ! -f "$latest_log" ]; then
        echo "No server log files found"
        return
    fi
    
    echo "=== Recent Server Activity ==="
    echo "Log file: $(basename "$latest_log")"
    
    # Get recent join/leave events
    local recent_joins=$(tail -n 100 "$latest_log" | grep -E "(joined|left) the game" | tail -5)
    if [ -n "$recent_joins" ]; then
        echo "Recent player activity:"
        echo "$recent_joins" | sed 's/^/  /'
    fi
    
    # Get recent errors or warnings
    local recent_errors=$(tail -n 100 "$latest_log" | grep -E "\[WARN\]|\[ERROR\]" | tail -3)
    if [ -n "$recent_errors" ]; then
        echo "Recent warnings/errors:"
        echo "$recent_errors" | sed 's/^/  /'
    fi
}

# Generate monitoring report
generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "=== Minecraft Server Monitor Report ==="
    echo "Timestamp: $timestamp"
    echo ""
    
    # Get and display metrics
    local metrics=$(get_server_metrics)
    
    if echo "$metrics" | grep -q "status=stopped"; then
        echo "Status: SERVER STOPPED"
        log_message "$MONITOR_LOG" "Server status: STOPPED"
        return
    fi
    
    echo "Status: RUNNING"
    echo ""
    
    # Parse and display metrics nicely
    echo "=== Process Information ==="
    echo "$metrics" | grep -E "pid|uptime" | while IFS='=' read -r key value; do
        case "$key" in
            pid) echo "Process ID: $value" ;;
            uptime) echo "Uptime: $value" ;;
        esac
    done
    
    echo ""
    echo "=== Performance Metrics ==="
    echo "$metrics" | grep -E "cpu_usage|mem_|load_avg" | while IFS='=' read -r key value; do
        case "$key" in
            cpu_usage) echo "CPU Usage: ${value}%" ;;
            mem_percent) echo "Java Memory: ${value}%" ;;
            mem_mb) echo "Java Memory: ${value}MB" ;;
            system_mem_percent) echo "System Memory: ${value}%" ;;
            load_avg) echo "Load Average: $value" ;;
        esac
    done
    
    echo ""
    echo "=== Storage Information ==="
    echo "$metrics" | grep -E "disk_" | while IFS='=' read -r key value; do
        case "$key" in
            disk_usage_percent) echo "Disk Usage: ${value}%" ;;
            disk_free_gb) echo "Free Space: ${value}GB" ;;
        esac
    done
    
    echo ""
    echo "=== Network Information ==="
    local connections=$(echo "$metrics" | grep "connections=" | cut -d'=' -f2)
    echo "Active Connections: $connections"
    
    echo ""
    check_alerts "$metrics"
    
    echo ""
    get_server_activity
}

# Log performance metrics to file
log_performance() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local metrics=$(get_server_metrics)
    
    # Create CSV header if file doesn't exist
    if [ ! -f "$LOG_DIR/performance.csv" ]; then
        echo "timestamp,status,cpu_usage,mem_percent,mem_mb,system_mem_percent,disk_usage_percent,disk_free_gb,load_avg,connections" > "$LOG_DIR/performance.csv"
    fi
    
    # Extract values and log to CSV
    local status=$(echo "$metrics" | grep "status=" | cut -d'=' -f2)
    local cpu_usage=$(echo "$metrics" | grep "cpu_usage=" | cut -d'=' -f2)
    local mem_percent=$(echo "$metrics" | grep "mem_percent=" | cut -d'=' -f2)
    local mem_mb=$(echo "$metrics" | grep "mem_mb=" | cut -d'=' -f2)
    local system_mem_percent=$(echo "$metrics" | grep "system_mem_percent=" | cut -d'=' -f2)
    local disk_usage=$(echo "$metrics" | grep "disk_usage_percent=" | cut -d'=' -f2)
    local disk_free=$(echo "$metrics" | grep "disk_free_gb=" | cut -d'=' -f2)
    local load_avg=$(echo "$metrics" | grep "load_avg=" | cut -d'=' -f2)
    local connections=$(echo "$metrics" | grep "connections=" | cut -d'=' -f2)
    
    echo "$timestamp,$status,$cpu_usage,$mem_percent,$mem_mb,$system_mem_percent,$disk_usage,$disk_free,$load_avg,$connections" >> "$LOG_DIR/performance.csv"
    
    # Check for alerts
    check_alerts "$metrics"
}

# Monitor continuously
start_monitoring() {
    log_message "$MONITOR_LOG" "Starting continuous monitoring (interval: ${MONITOR_INTERVAL}s)"
    echo "Starting Minecraft Server Monitoring..."
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    while true; do
        generate_report
        echo ""
        echo "=== Next update in ${MONITOR_INTERVAL} seconds ==="
        echo ""
        
        # Log performance data
        log_performance
        
        sleep "$MONITOR_INTERVAL"
        clear
    done
}

# Usage function
usage() {
    echo "Minecraft Server Monitor"
    echo "Usage: $0 {start|report|status|performance|help}"
    echo ""
    echo "Commands:"
    echo "  start       - Start continuous monitoring (runs in foreground)"
    echo "  report      - Generate a single monitoring report"
    echo "  status      - Quick server status check"
    echo "  performance - Log current performance metrics"
    echo "  help        - Show this help message"
    echo ""
    echo "For background monitoring, run: screen -dmS $MONITOR_SCREEN $0 start"
    exit 1
}

# ================= Main Script Logic =================
if [ $# -eq 0 ]; then
    usage
fi

case "$1" in
    start)
        start_monitoring
        ;;
    report)
        generate_report
        ;;
    status)
        metrics=$(get_server_metrics)
        if echo "$metrics" | grep -q "status=stopped"; then
            echo "Server Status: STOPPED"
        else
            echo "Server Status: RUNNING"
            echo "$metrics" | grep -E "cpu_usage|mem_percent|connections" | while IFS='=' read -r key value; do
                case "$key" in
                    cpu_usage) echo "CPU: ${value}%" ;;
                    mem_percent) echo "Memory: ${value}%" ;;
                    connections) echo "Connections: $value" ;;
                esac
            done
        fi
        ;;
    performance)
        log_performance
        echo "Performance metrics logged to $LOG_DIR/performance.csv"
        ;;
    help)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        ;;
esac
