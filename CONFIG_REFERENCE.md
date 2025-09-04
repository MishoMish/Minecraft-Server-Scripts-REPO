# ⚙️ Configuration Quick Reference

## 📝 Most Important Settings (config.sh)

### Memory Settings
```bash
MIN_RAM="6G"        # Starting memory (4G, 6G, 8G, 12G, etc.)
MAX_RAM="8G"        # Maximum memory (should be higher than MIN_RAM)
```

### Server File
```bash  
JAR_NAME="fabric.jar"    # Change if your server jar has different name
                        # Examples: "server.jar", "forge.jar", "paper.jar"
```

### Restart Schedule
```bash
RESTART_INTERVAL=14400   # Time between restarts in seconds
                        # 7200 = 2 hours, 14400 = 4 hours, 21600 = 6 hours
                        
WARN_TIMES=(600 300 60 30 10)  # When to warn players (seconds before restart)
                              # 600=10min, 300=5min, 60=1min, 30=30sec, 10=10sec
```

### Backup Settings
```bash
BACKUP_INTERVAL=21600    # Time between backups (21600 = 6 hours)
BACKUP_RETENTION=7       # How many backups to keep (older ones deleted)
```

---

## 🕒 Time Conversion Helper

| Hours | Seconds | Use For |
|-------|---------|---------|
| 1 hour | 3600 | Very frequent restarts |
| 2 hours | 7200 | Busy servers |
| 4 hours | 14400 | **Default - good for most** |
| 6 hours | 21600 | Less busy servers |
| 8 hours | 28800 | Very stable servers |
| 12 hours | 43200 | Rarely used |

---

## 🔧 Common Configuration Examples

### High-Performance Server (More RAM)
```bash
MIN_RAM="8G"
MAX_RAM="12G"
RESTART_INTERVAL=21600    # 6 hours
```

### Budget Server (Less RAM)
```bash
MIN_RAM="2G"
MAX_RAM="4G"
RESTART_INTERVAL=7200     # 2 hours (restart more often)
```

### Busy Server (More Warnings)
```bash
WARN_TIMES=(1800 900 600 300 60 30 10)  # 30min, 15min, 10min, 5min, 1min, 30s, 10s
```

### Quiet Server (Fewer Warnings)
```bash
WARN_TIMES=(300 60)       # Just 5 minutes and 1 minute warnings
```

### Backup-Heavy Server
```bash
BACKUP_INTERVAL=7200      # Backup every 2 hours
BACKUP_RETENTION=12       # Keep 12 backups (1 day worth)
```

---

## 📂 Directory Paths (Usually Don't Change These)

```bash
SCRIPT_DIR="[auto-detected]"           # Where scripts are located
SERVER_DIR="[auto-detected]/SERVER"    # Where Minecraft files are
LOG_DIR="$SCRIPT_DIR/logs"             # Where logs are stored
BACKUP_DIR="$SCRIPT_DIR/backups"       # Where backups are stored
```

---

## 🖥️ Screen Session Names (Don't Change Unless You Know What You're Doing)

```bash
SERVER_SCREEN="mcserver"     # Minecraft server console
RESTART_SCREEN="mcrestart"   # Auto-restart manager
MONITOR_SCREEN="mcmonitor"   # Performance monitor
BACKUP_SCREEN="mcbackup"     # Backup system
```

---

## 🚨 Alert Thresholds

```bash
MAX_MEMORY_PERCENT=90        # Alert when RAM usage > 90%
MAX_CPU_PERCENT=95          # Alert when CPU usage > 95%
MIN_FREE_DISK_GB=5          # Alert when free disk space < 5GB
```

---

## ⏱️ Monitoring Intervals

```bash
MONITOR_INTERVAL=30          # Check performance every 30 seconds
PERF_LOG_INTERVAL=300        # Log detailed performance every 5 minutes
```

---

## 🎯 Quick Setup Checklist

1. **Edit Memory**: Set `MIN_RAM` and `MAX_RAM` based on your container's memory
2. **Check Jar Name**: Make sure `JAR_NAME` matches your server file
3. **Set Restart Time**: Choose `RESTART_INTERVAL` based on how often you want restarts
4. **Configure Warnings**: Adjust `WARN_TIMES` for how much warning players get
5. **Backup Frequency**: Set `BACKUP_INTERVAL` for how often to backup

---

## 🔄 How to Apply Changes

After editing `config.sh`:

```bash
# Restart everything to apply changes
cd /root/scripts
./server-manager.sh stop
./server-manager.sh start
```

Or restart individual components:
```bash
./server-manager.sh server restart
./server-manager.sh auto-restart stop
./server-manager.sh auto-restart start
```
