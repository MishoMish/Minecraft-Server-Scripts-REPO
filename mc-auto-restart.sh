#!/bin/bash
# mc-auto-restart.sh - Advanced Minecraft Server Auto-Restart Manager
# Works with the new server-controller.sh for reliable restarts

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# ================= Helper Functions =================
usage() {
    echo "Minecraft Auto-Restart Manager"
    echo "Usage: $0 [-i interval] [-w warnings] [--dry-run] [--once]"
    echo ""
    echo "Options:"
    echo "  -i interval   Restart interval in seconds (default: from config)"
    echo "  -w warnings   Comma-separated warning times in seconds (default: from config)"
    echo "  --dry-run     Show what would happen without actually restarting"
    echo "  --once        Run one restart cycle and exit"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use default settings"
    echo "  $0 -i 7200 -w '900,300,60,10'       # 2 hour cycle with custom warnings"
    echo "  $0 --once                            # Single restart"
    echo ""
    exit 1
}

# Send notification to players
notify_players() {
    local message="$1"
    local urgency="$2"  # normal, warning, urgent
    
    case "$urgency" in
        warning)
            message="§e[WARNING]§r $message"
            ;;
        urgent)
            message="§c[URGENT]§r $message"
            ;;
        *)
            message="§a[INFO]§r $message"
            ;;
    esac
    
    if "$SCRIPT_DIR/server-controller.sh" send "say $message" >/dev/null 2>&1; then
        log_message "$RESTART_LOG" "Notification sent: $message"
        return 0
    else
        log_message "$RESTART_LOG" "Failed to send notification: $message"
        return 1
    fi
}

# Check if server is ready for restart
is_server_ready() {
    # Check if server is running
    if ! screen_exists "$SERVER_SCREEN"; then
        log_message "$RESTART_LOG" "Server is not running, cannot restart"
        return 1
    fi
    
    # Additional checks can be added here (e.g., no recent joins, low activity)
    return 0
}

# Perform server restart
perform_restart() {
    local dry_run="$1"
    
    log_message "$RESTART_LOG" "Starting restart procedure (dry_run=$dry_run)"
    
    if [ "$dry_run" = "true" ]; then
        echo "[DRY RUN] Would restart server now"
        log_message "$RESTART_LOG" "DRY RUN: Would restart server"
        return 0
    fi
    
    if ! is_server_ready; then
        echo "[ERROR] Server is not ready for restart"
        return 1
    fi
    
    # Send final notification
    notify_players "Server restarting now! Back online in ~30 seconds..." "urgent"
    sleep 2
    
    # Use the server controller to restart
    echo "[INFO] Restarting server using controller..."
    if "$SCRIPT_DIR/server-controller.sh" restart; then
        log_message "$RESTART_LOG" "Server restart completed successfully"
        
        # Wait a bit and send confirmation
        sleep 10
        notify_players "Server restart complete! Welcome back!" "normal"
        return 0
    else
        log_message "$RESTART_LOG" "Server restart failed!"
        echo "[ERROR] Server restart failed!"
        return 1
    fi
}

# Send warning notifications
send_warnings() {
    local total_time="$1"
    local dry_run="$2"
    local warnings=("${@:3}")
    
    # Sort warnings in descending order
    IFS=$'\n' warnings=($(sort -rn <<<"${warnings[*]}")); unset IFS
    
    local start_time=$(date +%s)
    local end_time=$((start_time + total_time))
    
    for warn_time in "${warnings[@]}"; do
        local notify_at=$((end_time - warn_time))
        local current_time=$(date +%s)
        
        if [ "$notify_at" -le "$current_time" ]; then
            continue  # Skip if warning time has already passed
        fi
        
        local sleep_time=$((notify_at - current_time))
        
        if [ "$sleep_time" -gt 0 ]; then
            echo "[INFO] Sleeping $sleep_time seconds until next warning ($warn_time seconds before restart)..."
            sleep "$sleep_time"
        fi
        
        # Format time nicely
        local time_str=""
        if [ "$warn_time" -ge 3600 ]; then
            local hours=$((warn_time / 3600))
            local minutes=$(((warn_time % 3600) / 60))
            time_str="${hours}h ${minutes}m"
        elif [ "$warn_time" -ge 60 ]; then
            local minutes=$((warn_time / 60))
            local seconds=$((warn_time % 60))
            if [ "$seconds" -eq 0 ]; then
                time_str="${minutes} minutes"
            else
                time_str="${minutes}m ${seconds}s"
            fi
        else
            time_str="$warn_time seconds"
        fi
        
        local urgency="normal"
        [ "$warn_time" -le 300 ] && urgency="warning"  # 5 minutes or less
        [ "$warn_time" -le 60 ] && urgency="urgent"    # 1 minute or less
        
        local message="Scheduled restart in $time_str! Save your progress!"
        
        if [ "$dry_run" = "true" ]; then
            echo "[DRY RUN] Would send warning: $message"
        else
            echo "[INFO] Sending $warn_time second warning..."
            notify_players "$message" "$urgency"
        fi
    done
    
    # Sleep any remaining time
    local current_time=$(date +%s)
    local remaining_time=$((end_time - current_time))
    if [ "$remaining_time" -gt 0 ]; then
        echo "[INFO] Sleeping final $remaining_time seconds..."
        sleep "$remaining_time"
    fi
}

# Main restart cycle
run_restart_cycle() {
    local interval="$1"
    local warnings=("${@:2}")
    local dry_run="${dry_run:-false}"
    
    local next_restart=$(date -d "+$interval seconds" '+%Y-%m-%d %H:%M:%S')
    
    echo "=== Auto-Restart Cycle Started ==="
    echo "Restart interval: $interval seconds ($((interval / 60)) minutes)"
    echo "Warning times: ${warnings[*]} seconds"
    echo "Next restart: $next_restart"
    echo "Dry run mode: $dry_run"
    echo ""
    
    log_message "$RESTART_LOG" "Auto-restart cycle started: interval=${interval}s, warnings=(${warnings[*]})"
    
    # Send initial notification if server is running
    if screen_exists "$SERVER_SCREEN"; then
        local hours=$((interval / 3600))
        local minutes=$(((interval % 3600) / 60))
        local time_str=""
        if [ "$hours" -gt 0 ]; then
            time_str="${hours}h ${minutes}m"
        else
            time_str="${minutes} minutes"
        fi
        
        if [ "$dry_run" = "false" ]; then
            notify_players "Auto-restart scheduled in $time_str" "normal"
        fi
    fi
    
    # Send warnings and perform restart
    send_warnings "$interval" "$dry_run" "${warnings[@]}"
    perform_restart "$dry_run"
}

# ================= Parse Options =================
dry_run=false
once=false
custom_interval=""
custom_warnings=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interval)
            custom_interval="$2"
            shift 2
            ;;
        -w|--warnings)
            custom_warnings="$2"
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --once)
            once=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Set intervals and warnings
interval="${custom_interval:-$RESTART_INTERVAL}"
if [ -n "$custom_warnings" ]; then
    IFS=',' read -ra warn_array <<< "$custom_warnings"
else
    warn_array=("${WARN_TIMES[@]}")
fi

# Validate interval
if ! [[ "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -lt 60 ]; then
    echo "Error: Invalid interval. Must be a number >= 60 seconds"
    exit 1
fi

# ================= Main Script Logic =================
echo "Minecraft Auto-Restart Manager"
echo "==============================="

# Check if server controller exists
if [ ! -x "$SCRIPT_DIR/server-controller.sh" ]; then
    echo "Error: server-controller.sh not found or not executable"
    exit 1
fi

if [ "$once" = "true" ]; then
    echo "Running single restart cycle..."
    run_restart_cycle "$interval" "${warn_array[@]}"
else
    echo "Starting continuous auto-restart manager..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    # Main loop
    while true; do
        run_restart_cycle "$interval" "${warn_array[@]}"
        
        if [ "$dry_run" = "true" ]; then
            echo "[DRY RUN] Cycle complete, exiting..."
            break
        fi
        
        echo ""
        echo "=== Restart cycle completed, starting next cycle ==="
        echo ""
        sleep 5  # Small delay between cycles
    done
fi
