#!/bin/bash
# config.sh - Centralized configuration for Minecraft Server Management Platform
# This file contains all the configuration variables used across all scripts

# ================= Directory Configuration =================
# Base directory where scripts are located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Server directory (absolute path)
SERVER_DIR="/root/SERVER"

# Logs directory
LOG_DIR="$SCRIPT_DIR/logs"

# Backup directory
BACKUP_DIR="$SCRIPT_DIR/backups"

# ================= Server Configuration =================
# Minecraft server jar file
JAR_NAME="fabric.jar"

# Memory allocation
MIN_RAM="6G"
MAX_RAM="8G"

# Java options
JAVA_OPTS="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"

# ================= Screen Session Names =================
SERVER_SCREEN="mcserver"
RESTART_SCREEN="mcrestart"
MONITOR_SCREEN="mcmonitor"
BACKUP_SCREEN="mcbackup"

# ================= Auto-restart Configuration =================
# Restart interval in seconds (default: 4 hours = 14400 seconds)
RESTART_INTERVAL=14400

# Warning times in seconds before restart
WARN_TIMES=(600 300 60 30 10)

# ================= Monitoring Configuration =================
# Monitor update interval in seconds
MONITOR_INTERVAL=30

# Performance log interval in seconds
PERF_LOG_INTERVAL=300

# Alert thresholds
MAX_MEMORY_PERCENT=90
MAX_CPU_PERCENT=95
MIN_FREE_DISK_GB=5

# ================= Backup Configuration =================
# Automatic backup interval in seconds (default: 6 hours = 21600 seconds)
BACKUP_INTERVAL=21600

# Number of backups to keep
BACKUP_RETENTION=7

# ================= Logging Configuration =================
# Log file names
SERVER_LOG="$LOG_DIR/server.log"
RESTART_LOG="$LOG_DIR/restart.log"
MONITOR_LOG="$LOG_DIR/monitor.log"
BACKUP_LOG="$LOG_DIR/backup.log"
MANAGER_LOG="$LOG_DIR/manager.log"

# Log rotation settings
MAX_LOG_SIZE="100M"
MAX_LOG_FILES=5

# ================= Network Configuration =================
# Default server port
SERVER_PORT=25565

# RCON settings (if enabled)
RCON_PORT=25575
RCON_ENABLED=false

# ================= Helper Functions =================
# Function to log messages with timestamp
log_message() {
    local log_file="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$log_file"
}

# Function to check if a screen session exists
screen_exists() {
    screen -list | grep -q "$1"
}

# Function to send command to server screen
send_server_command() {
    local cmd="$1"
    if screen_exists "$SERVER_SCREEN"; then
        screen -S "$SERVER_SCREEN" -X stuff "$cmd$(printf \\r)"
        return 0
    else
        echo "Error: Server screen session not found"
        return 1
    fi
}

# Function to create necessary directories
init_directories() {
    mkdir -p "$LOG_DIR" "$BACKUP_DIR"
    if [ ! -d "$SERVER_DIR" ]; then
        echo "Warning: Server directory '$SERVER_DIR' does not exist"
        echo "Please create it and place your Minecraft server files there"
    fi
}

# Initialize directories when config is sourced
init_directories

# Export important variables for use in other scripts
export SCRIPT_DIR SERVER_DIR LOG_DIR BACKUP_DIR
export JAR_NAME MIN_RAM MAX_RAM JAVA_OPTS
export SERVER_SCREEN RESTART_SCREEN MONITOR_SCREEN BACKUP_SCREEN
export RESTART_INTERVAL MONITOR_INTERVAL BACKUP_INTERVAL
export SERVER_LOG RESTART_LOG MONITOR_LOG BACKUP_LOG MANAGER_LOG
