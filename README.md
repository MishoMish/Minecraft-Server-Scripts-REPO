# Mi## 📚 Documentation

- **🎮 [BEGINNER_GUIDE.md](BEGINNER_GUIDE.md)** - **Start here!** Complete guide for non-technical users
- **🔄 [STARTUP_PROCESS.md](STARTUP_PROCESS.md)** - Detailed explanation of what happens when container starts
- **⚙️ [CONFIG_REFERENCE.md](CONFIG_REFERENCE.md)** - Quick reference for all configuration options
- **📖 [README.md](README.md)** - This file (technical overview)ft Server Management Platform

A comprehensive, modular Minecraft server management system designed for Proxmox LXC containers with automatic restarts, monitoring, backups, and easy administration.

## � Documentation

- **🎮 [BEGINNER_GUIDE.md](BEGINNER_GUIDE.md)** - **Start here!** Complete guide for non-technical users
- **🔄 [STARTUP_PROCESS.md](STARTUP_PROCESS.md)** - Detailed explanation of what happens when container starts
- **📖 [README.md](README.md)** - This file (technical overview)

## 🚀 Quick Start

### For Beginners
👉 **Read [BEGINNER_GUIDE.md](BEGINNER_GUIDE.md) first!** 👈

### For Technical Users
1. Copy scripts to `/root/scripts/` in your LXC container
2. Copy Minecraft server files to `/root/SERVER/`
3. Edit `/root/scripts/config.sh` with your settings
4. Run `/root/scripts/start-with-management.sh` on container startup
5. Use `/root/scripts/server-manager.sh status` to check everything

## 🎯 What This System Does

✅ **Auto-starts** when your Proxmox LXC container boots  
✅ **Manages** your Minecraft server with proper start/stop procedures  
✅ **Monitors** performance (CPU, RAM, disk) with alerts  
✅ **Restarts** server automatically every few hours to prevent lag  
✅ **Warns players** before restarts with configurable timing  
✅ **Creates backups** automatically with compression and rotation  
✅ **Logs everything** for easy troubleshooting  
✅ **Runs in screen sessions** so you can monitor each component  

## 📁 Essential Files

| File | Purpose | Edit This? |
|------|---------|------------|
| `config.sh` | **All your settings** | ✅ YES |
| `server-manager.sh` | Main control panel | ❌ No |
| `start-with-management.sh` | Auto-startup script | ❌ No |
| `BEGINNER_GUIDE.md` | User documentation | 📖 Read |

## �️ Screen Sessions

When running, you'll have these background processes:

| Session | Purpose | View With |
|---------|---------|-----------|
| `mcserver` | Minecraft server console | `screen -r mcserver` |
| `mcrestart` | Auto-restart manager | `screen -r mcrestart` |
| `mcmonitor` | Performance monitoring | `screen -r mcmonitor` |
| `mcbackup` | Backup system | `screen -r mcbackup` |

**Exit screens safely:** `Ctrl+A` then `D`

## ⚙️ Key Configuration Options

Edit `/root/scripts/config.sh`:

```bash
# Memory settings
MIN_RAM="6G"
MAX_RAM="8G"

# Restart timing (seconds)
RESTART_INTERVAL=14400  # 4 hours

# Warning schedule (seconds before restart)
WARN_TIMES=(600 300 60 30 10)  # 10min, 5min, 1min, 30s, 10s

# Backup settings  
BACKUP_INTERVAL=21600   # 6 hours
BACKUP_RETENTION=7      # Keep 7 backups
```

## 🎮 Daily Commands

```bash
cd /root/scripts

# Check everything
./server-manager.sh status

# View server console  
screen -r mcserver

# Send server command
./server-manager.sh send "time set day"

# Restart now
./server-manager.sh restart

# Create backup
./backup.sh create manual
```
