#!/bin/bash
# backup.sh - Minecraft Server Backup System
# Handles automatic and manual backups with compression and rotation

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# ================= Backup Functions =================

# Create a backup of the server world
create_backup() {
    local backup_type="$1"  # manual, auto, scheduled
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local backup_name="minecraft_backup_${backup_type}_${timestamp}.tar.gz"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    echo "=== Creating Minecraft Server Backup ==="
    echo "Type: $backup_type"
    echo "Timestamp: $timestamp"
    echo "Backup file: $backup_name"
    echo ""
    
    log_message "$BACKUP_LOG" "Starting $backup_type backup: $backup_name"
    
    # Check if server directory exists
    if [ ! -d "$SERVER_DIR" ]; then
        echo "Error: Server directory not found: $SERVER_DIR"
        log_message "$BACKUP_LOG" "Error: Server directory not found"
        return 1
    fi
    
    # Force save if server is running
    local server_was_running=false
    if screen_exists "$SERVER_SCREEN"; then
        echo "Server is running, forcing save before backup..."
        send_server_command "say Creating backup... Server may lag briefly."
        send_server_command "save-all"
        send_server_command "save-off"  # Disable auto-save during backup
        sleep 5
        server_was_running=true
    fi
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Create the backup
    echo "Creating compressed backup..."
    local start_time=$(date +%s)
    
    cd "$(dirname "$SERVER_DIR")" || {
        echo "Error: Cannot change to parent directory of server"
        log_message "$BACKUP_LOG" "Error: Cannot change to server parent directory"
        return 1
    }
    
    # Exclude unnecessary files and directories
    tar -czf "$backup_path" \
        --exclude="$(basename "$SERVER_DIR")/cache" \
        --exclude="$(basename "$SERVER_DIR")/crash-reports" \
        --exclude="$(basename "$SERVER_DIR")/debug" \
        --exclude="$(basename "$SERVER_DIR")/logs/*.log.*" \
        --exclude="$(basename "$SERVER_DIR")/logs/*.gz" \
        --exclude="$(basename "$SERVER_DIR")/usercache.json" \
        --exclude="$(basename "$SERVER_DIR")/.fabric" \
        "$(basename "$SERVER_DIR")" 2>/dev/null
    
    local exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Re-enable auto-save if server was running
    if [ "$server_was_running" = true ]; then
        send_server_command "save-on"
        send_server_command "say Backup completed successfully!"
    fi
    
    if [ $exit_code -eq 0 ] && [ -f "$backup_path" ]; then
        local backup_size=$(du -h "$backup_path" | cut -f1)
        echo "Backup created successfully!"
        echo "File: $backup_path"
        echo "Size: $backup_size"
        echo "Duration: ${duration}s"
        
        log_message "$BACKUP_LOG" "Backup completed: $backup_name (${backup_size}, ${duration}s)"
        
        # Clean up old backups
        cleanup_old_backups
        
        return 0
    else
        echo "Error: Backup failed!"
        log_message "$BACKUP_LOG" "Error: Backup failed"
        rm -f "$backup_path"  # Remove partial backup
        return 1
    fi
}

# Restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        echo "Error: Backup file not specified"
        echo "Usage: $0 restore <backup_file>"
        list_backups
        return 1
    fi
    
    # Check if backup file exists (try both absolute path and relative to backup dir)
    local backup_path=""
    if [ -f "$backup_file" ]; then
        backup_path="$backup_file"
    elif [ -f "$BACKUP_DIR/$backup_file" ]; then
        backup_path="$BACKUP_DIR/$backup_file"
    else
        echo "Error: Backup file not found: $backup_file"
        echo "Available backups:"
        list_backups
        return 1
    fi
    
    echo "=== Restoring Minecraft Server from Backup ==="
    echo "Backup file: $backup_path"
    echo ""
    
    # Check if server is running
    if screen_exists "$SERVER_SCREEN"; then
        echo "Error: Server is currently running!"
        echo "Please stop the server before restoring a backup."
        return 1
    fi
    
    # Confirm restoration
    echo "WARNING: This will replace the current server files!"
    echo "Current server directory: $SERVER_DIR"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Restoration cancelled."
        return 1
    fi
    
    log_message "$BACKUP_LOG" "Starting restoration from: $(basename "$backup_path")"
    
    # Create backup of current server (just in case)
    if [ -d "$SERVER_DIR" ]; then
        echo "Creating safety backup of current server..."
        local safety_backup="$BACKUP_DIR/safety_backup_$(date '+%Y-%m-%d_%H-%M-%S').tar.gz"
        tar -czf "$safety_backup" -C "$(dirname "$SERVER_DIR")" "$(basename "$SERVER_DIR")" 2>/dev/null
        echo "Safety backup created: $(basename "$safety_backup")"
    fi
    
    # Remove current server directory
    if [ -d "$SERVER_DIR" ]; then
        echo "Removing current server files..."
        rm -rf "$SERVER_DIR"
    fi
    
    # Extract backup
    echo "Extracting backup..."
    mkdir -p "$(dirname "$SERVER_DIR")"
    cd "$(dirname "$SERVER_DIR")" || {
        echo "Error: Cannot change to server parent directory"
        return 1
    }
    
    if tar -xzf "$backup_path" 2>/dev/null; then
        echo "Backup restored successfully!"
        echo "Server directory: $SERVER_DIR"
        log_message "$BACKUP_LOG" "Restoration completed successfully"
        return 0
    else
        echo "Error: Failed to extract backup!"
        log_message "$BACKUP_LOG" "Error: Restoration failed"
        return 1
    fi
}

# List available backups
list_backups() {
    echo "=== Available Backups ==="
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.tar.gz 2>/dev/null)" ]; then
        echo "No backups found in $BACKUP_DIR"
        return 0
    fi
    
    echo "Location: $BACKUP_DIR"
    echo ""
    
    # List backups with details
    ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null | while read -r perms links owner group size month day time file; do
        local basename_file=$(basename "$file")
        local backup_type="unknown"
        
        # Extract backup type from filename
        if [[ "$basename_file" == *"_manual_"* ]]; then
            backup_type="manual"
        elif [[ "$basename_file" == *"_auto_"* ]]; then
            backup_type="auto"
        elif [[ "$basename_file" == *"_scheduled_"* ]]; then
            backup_type="scheduled"
        elif [[ "$basename_file" == *"safety_backup"* ]]; then
            backup_type="safety"
        fi
        
        printf "%-50s %8s %-10s %s %s %s\n" "$basename_file" "$size" "$backup_type" "$month" "$day" "$time"
    done
}

# Clean up old backups based on retention policy
cleanup_old_backups() {
    if [ "$BACKUP_RETENTION" -le 0 ]; then
        return 0  # Retention disabled
    fi
    
    local backup_count=$(find "$BACKUP_DIR" -name "minecraft_backup_*.tar.gz" -type f | wc -l)
    
    if [ "$backup_count" -gt "$BACKUP_RETENTION" ]; then
        local excess=$((backup_count - BACKUP_RETENTION))
        echo "Cleaning up $excess old backup(s) (retention: $BACKUP_RETENTION)..."
        
        find "$BACKUP_DIR" -name "minecraft_backup_*.tar.gz" -type f -printf '%T@ %p\n' | \
        sort -k 1n | head -n "$excess" | cut -d' ' -f2- | \
        while read -r old_backup; do
            echo "Removing old backup: $(basename "$old_backup")"
            rm -f "$old_backup"
            log_message "$BACKUP_LOG" "Removed old backup: $(basename "$old_backup")"
        done
    fi
}

# Start automatic backup system
start_backup_daemon() {
    echo "Starting automatic backup system..."
    echo "Backup interval: $BACKUP_INTERVAL seconds ($((BACKUP_INTERVAL / 3600)) hours)"
    echo "Backup retention: $BACKUP_RETENTION backups"
    echo "Press Ctrl+C to stop"
    echo ""
    
    log_message "$BACKUP_LOG" "Automatic backup system started (interval: ${BACKUP_INTERVAL}s)"
    
    while true; do
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Next backup in $((BACKUP_INTERVAL / 3600)) hours..."
        sleep "$BACKUP_INTERVAL"
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting scheduled backup..."
        if create_backup "scheduled"; then
            echo "Scheduled backup completed successfully"
        else
            echo "Scheduled backup failed!"
        fi
        echo ""
    done
}

# Get backup statistics
backup_stats() {
    echo "=== Backup Statistics ==="
    echo "Backup directory: $BACKUP_DIR"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Backup directory does not exist"
        return 0
    fi
    
    local total_backups=$(find "$BACKUP_DIR" -name "*.tar.gz" -type f | wc -l)
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    local oldest_backup=$(find "$BACKUP_DIR" -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -k 1n | head -1 | cut -d' ' -f2-)
    local newest_backup=$(find "$BACKUP_DIR" -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -k 1nr | head -1 | cut -d' ' -f2-)
    
    echo "Total backups: $total_backups"
    echo "Total size: ${total_size:-0}"
    echo "Retention policy: $BACKUP_RETENTION backups"
    
    if [ -n "$oldest_backup" ]; then
        echo "Oldest backup: $(basename "$oldest_backup")"
        echo "Newest backup: $(basename "$newest_backup")"
    fi
    
    echo ""
    echo "Backup types:"
    find "$BACKUP_DIR" -name "*.tar.gz" -type f 2>/dev/null | while read -r backup; do
        local basename_file=$(basename "$backup")
        if [[ "$basename_file" == *"_manual_"* ]]; then
            echo "manual"
        elif [[ "$basename_file" == *"_auto_"* ]]; then
            echo "auto"
        elif [[ "$basename_file" == *"_scheduled_"* ]]; then
            echo "scheduled"
        elif [[ "$basename_file" == *"safety_backup"* ]]; then
            echo "safety"
        else
            echo "unknown"
        fi
    done | sort | uniq -c | while read -r count type; do
        printf "  %-10s: %d\n" "$type" "$count"
    done
}

# Usage function
usage() {
    echo "Minecraft Server Backup System"
    echo "Usage: $0 {create|restore|list|cleanup|start|stats|help} [options]"
    echo ""
    echo "Commands:"
    echo "  create [type]     - Create a backup (type: manual, auto)"
    echo "  restore <file>    - Restore from backup file"
    echo "  list             - List available backups"
    echo "  cleanup          - Clean up old backups manually"
    echo "  start            - Start automatic backup daemon"
    echo "  stats            - Show backup statistics"
    echo "  help             - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 create manual                    # Create manual backup"
    echo "  $0 restore minecraft_backup_*.tar.gz  # Restore from backup"
    echo "  $0 list                             # List all backups"
    echo ""
    exit 1
}

# ================= Main Script Logic =================
if [ $# -eq 0 ]; then
    usage
fi

case "$1" in
    create)
        backup_type="${2:-manual}"
        create_backup "$backup_type"
        ;;
    restore)
        restore_backup "$2"
        ;;
    list)
        list_backups
        ;;
    cleanup)
        echo "Cleaning up old backups..."
        cleanup_old_backups
        echo "Cleanup completed!"
        ;;
    start)
        start_backup_daemon
        ;;
    stats)
        backup_stats
        ;;
    help)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        ;;
esac
