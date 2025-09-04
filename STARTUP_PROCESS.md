# 🔄 Container Startup Process - Step by Step

This document explains exactly what happens when your Proxmox LXC container starts up and how the Minecraft server management system initializes.

---

## 🚀 Container Boot Sequence

### 1. LXC Container Starts
```
Proxmox → Starts LXC Container → Container OS Boots → Runs startup scripts
```

### 2. Auto-Start Trigger
The container automatically runs: `/root/scripts/start-with-management.sh`

**How this happens:**
- Added to `/etc/rc.local` during setup
- Runs after all system services are started
- Runs as root user

---

## 📋 Detailed Startup Steps

### Phase 1: System Preparation (start-with-management.sh)

```bash
STEP 1: Load Configuration
- Sources /root/scripts/config.sh
- Sets all variables (RAM, paths, screen names, etc.)
- Creates log entry with timestamp

STEP 2: Wait for System Ready
- Sleeps 10 seconds to ensure container is fully booted
- Allows network and file system to be ready

STEP 3: Verify Directory Structure  
- Checks if /root/SERVER exists
- Warns if Minecraft server files missing
- Creates logs/ and backups/ directories if needed

STEP 4: Set Permissions
- Makes all .sh files executable (chmod +x)
- Ensures scripts can run properly

STEP 5: Clean Up Previous Sessions
- Kills any old screen sessions from previous runs:
  * mcserver (old Minecraft server)
  * mcrestart (old auto-restart manager)  
  * mcmonitor (old performance monitor)
  * mcbackup (old backup system)
- Waits 3 seconds for cleanup to complete
```

### Phase 2: Start Management Platform

```bash
STEP 6: Launch Server Manager
- Runs: /root/scripts/server-manager.sh start
- This orchestrates starting all components

STEP 7: Start Minecraft Server (server-manager.sh → server-controller.sh)
- Creates screen session "mcserver"
- Changes to /root/SERVER directory
- Runs: java -Xms6G -Xmx8G [optimized flags] -jar fabric.jar nogui
- Waits up to 2 minutes for server to fully start
- Checks for "Done" or "Server started" message

STEP 8: Start Auto-Restart Manager
- Creates screen session "mcrestart"  
- Runs: /root/scripts/mc-auto-restart.sh
- Begins countdown timer for next restart (default: 4 hours)
- Sends initial notification to players

STEP 9: Start Performance Monitor
- Creates screen session "mcmonitor"
- Runs: /root/scripts/monitor.sh start
- Begins monitoring CPU, RAM, disk usage every 30 seconds
- Logs performance data to CSV file

STEP 10: Start Backup System  
- Creates screen session "mcbackup"
- Runs: /root/scripts/backup.sh start
- Schedules automatic backups (default: every 6 hours)
- Sets up backup rotation (keeps 7 backups)
```

### Phase 3: Startup Completion

```bash
STEP 11: Verify All Components
- Checks that all screen sessions are running
- Logs success/failure for each component
- Reports final status

STEP 12: Display Status Information
- Shows which screen sessions are active
- Provides helpful commands for management
- Logs completion to manager.log
```

---

## 🖥️ What You See During Startup

### Console Output Example:
```
=== Minecraft Server Management Platform Startup ===
Script Directory: /root/scripts
Server Directory: /root/SERVER
Container Startup Time: 2025-09-04 15:30:25

Waiting for system initialization...
Checking directory structure...
Setting script permissions...
Cleaning up old screen sessions...
Terminating old screen session: mcserver
Terminating old screen session: mcrestart

Starting Minecraft Server Management Platform...

Starting Minecraft Server...
Server started successfully in screen: mcserver
Starting Auto-restart Manager...
Auto-restart Manager started successfully in screen: mcrestart  
Starting Performance Monitor...
Performance Monitor started successfully in screen: mcmonitor
Starting Backup System...
Backup System started successfully in screen: mcbackup

=== Startup Complete ===
All components have been started successfully!

Available screen sessions:
There are screens on:
    12345.mcserver    (Detached)
    12346.mcrestart   (Detached) 
    12347.mcmonitor   (Detached)
    12348.mcbackup    (Detached)

Management commands:
  Status:      /root/scripts/server-manager.sh status
  Console:     screen -r mcserver
  Monitor:     screen -r mcmonitor
  Auto-restart: screen -r mcrestart
  Help:        /root/scripts/server-manager.sh help

To detach from any screen session: Ctrl+A, then D
```

---

## ⚙️ Configuration Values Used During Startup

All these values come from `/root/scripts/config.sh`:

### Directory Paths
```bash
SCRIPT_DIR="/root/scripts"              # Where all management scripts are
SERVER_DIR="/root/SERVER"               # Where Minecraft server files are  
LOG_DIR="/root/scripts/logs"            # Where log files are stored
BACKUP_DIR="/root/scripts/backups"      # Where backups are stored
```

### Minecraft Server Settings
```bash
JAR_NAME="fabric.jar"                   # Server jar filename
MIN_RAM="6G"                           # Starting memory allocation
MAX_RAM="8G"                           # Maximum memory allocation
JAVA_OPTS="[optimized JVM flags]"      # Performance optimizations
```

### Screen Session Names
```bash
SERVER_SCREEN="mcserver"                # Minecraft server console
RESTART_SCREEN="mcrestart"              # Auto-restart manager
MONITOR_SCREEN="mcmonitor"              # Performance monitor  
BACKUP_SCREEN="mcbackup"                # Backup system
```

### Timing Configuration
```bash
RESTART_INTERVAL=14400                  # 4 hours between restarts
WARN_TIMES=(600 300 60 30 10)          # Warning schedule (seconds)
MONITOR_INTERVAL=30                     # Performance check frequency
BACKUP_INTERVAL=21600                   # 6 hours between backups
BACKUP_RETENTION=7                      # Keep 7 backup files
```

---

## 🔍 How Each Component Works After Startup

### 1. Minecraft Server (mcserver screen)
```bash
Continuously runs: java -Xms6G -Xmx8G -jar fabric.jar nogui
- Accepts player connections on port 25565
- Processes game commands and world simulation  
- Logs all activity to server console
- Automatically saves world data periodically
```

### 2. Auto-Restart Manager (mcrestart screen)
```bash
Runs: /root/scripts/mc-auto-restart.sh
Every 4 hours (configurable):
  1. Waits until 10 minutes before restart
  2. Sends warning: "Server will restart in 10 minutes!"
  3. Waits until 5 minutes before restart  
  4. Sends warning: "Server will restart in 5 minutes!"
  5. Continues with 1min, 30sec, 10sec warnings
  6. Saves world data
  7. Stops server gracefully
  8. Starts server again
  9. Confirms restart to players
```

### 3. Performance Monitor (mcmonitor screen)  
```bash
Runs: /root/scripts/monitor.sh start
Every 30 seconds:
  1. Checks Java process CPU usage
  2. Checks memory consumption  
  3. Checks disk space available
  4. Counts active network connections
  5. Logs data to performance.csv
  6. Alerts if thresholds exceeded:
     - CPU > 95%
     - Memory > 90% 
     - Free disk < 5GB
```

### 4. Backup System (mcbackup screen)
```bash  
Runs: /root/scripts/backup.sh start
Every 6 hours (configurable):
  1. Sends "Creating backup..." to players
  2. Forces world save with "save-all"
  3. Temporarily disables auto-save
  4. Creates compressed tar.gz of entire SERVER/
  5. Re-enables auto-save
  6. Removes old backups (keeps newest 7)
  7. Confirms backup completion to players
```

---

## 🔧 Customizing the Startup Process

### Change Memory Allocation
Edit `/root/scripts/config.sh`:
```bash
MIN_RAM="4G"    # Reduce starting memory
MAX_RAM="6G"    # Reduce maximum memory
```

### Change Restart Frequency  
Edit `/root/scripts/config.sh`:
```bash
RESTART_INTERVAL=28800    # 8 hours instead of 4
```

### Disable Specific Components
Edit `/root/scripts/start-with-management.sh` and comment out:
```bash
# start_component "Backup System" "$BACKUP_SCREEN" "$SCRIPT_DIR/backup.sh" "start"
```

### Change Java Optimization Flags
Edit `/root/scripts/config.sh` and modify `JAVA_OPTS`:
```bash
JAVA_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=200"  # Simpler flags
```

---

## 🚨 Startup Failure Scenarios

### If Minecraft Server Fails to Start:
```
Possible causes:
- fabric.jar not found in /root/SERVER/
- Not enough RAM available
- Port 25565 already in use
- Corrupted world data

Check: ./server-manager.sh status
View logs: ./server-manager.sh logs server
```

### If Screen Sessions Don't Start:
```
Possible causes:  
- Scripts not executable (chmod +x *.sh)
- Path issues in configuration
- Previous sessions not cleaned up

Fix: screen -wipe && ./server-manager.sh start
```

### If Auto-restart Doesn't Work:
```
Possible causes:
- Server controller script not found
- Configuration syntax error
- Insufficient permissions

Check: screen -r mcrestart (view error messages)
```

---

This startup process ensures your Minecraft server is always running reliably and managed automatically, even after container reboots or crashes.
