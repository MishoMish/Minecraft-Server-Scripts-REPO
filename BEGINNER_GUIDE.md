# 🎮 Minecraft Server Management - Beginner's Guide

## What This Does
This system automatically manages your Minecraft server in a Proxmox LXC container. When your container starts, it will:
1. **Start your Minecraft server**
2. **Monitor server performance** (CPU, memory, players)
3. **Automatically restart** the server every few hours to keep it running smoothly
4. **Create backups** of your world regularly
5. **Send warnings** to players before restarts

Everything runs in the background, and you can easily check on it or control it.

---

## 📁 What Files Do What

### Core Scripts (Don't Delete These!)

| File | What It Does | Do I Need To Edit This? |
|------|--------------|------------------------|
| `config.sh` | **All your settings** - memory, restart times, etc. | **YES** - This is where you change everything |
| `server-manager.sh` | **Main control panel** - start/stop everything | No - Just use the commands |
| `server-controller.sh` | Controls the Minecraft server itself | No - Just use the commands |
| `start-with-management.sh` | **Auto-starts everything** when container boots | No - Proxmox runs this automatically |

### Optional Features
| File | What It Does | Do I Need This? |
|------|--------------|-----------------|
| `monitor.sh` | Watches server performance and creates reports | Optional - Nice to have |
| `mc-auto-restart.sh` | Handles automatic server restarts | Yes - Keeps server healthy |
| `backup.sh` | Creates backups of your world | Optional - But recommended! |
| `start.sh` | Starts just the Minecraft server | No - Used by other scripts |

---

## 🚀 First Time Setup (Do This Once)

### Step 1: Set Up Your Container
```bash
# In your Proxmox LXC container, create these folders:
mkdir -p /root/scripts
mkdir -p /root/SERVER

# Copy all the script files to /root/scripts/
# Copy your Minecraft server files (fabric.jar, mods, world, etc.) to /root/SERVER/
```

### Step 2: Edit Your Settings
Open `/root/scripts/config.sh` and change these settings:

```bash
# How much RAM to give Minecraft (change these numbers!)
MIN_RAM="6G"        # Starting RAM
MAX_RAM="8G"        # Maximum RAM

# What's your server jar file called?
JAR_NAME="fabric.jar"  # Change if your file is named differently

# How often to restart (in seconds)
RESTART_INTERVAL=14400  # 14400 = 4 hours, 7200 = 2 hours, 21600 = 6 hours

# When to warn players before restart (in seconds)
WARN_TIMES=(600 300 60 30 10)  # 10min, 5min, 1min, 30sec, 10sec warnings
```

### Step 3: Make Container Auto-Start This System
Add this line to your LXC container's startup:
```bash
echo "/root/scripts/start-with-management.sh" >> /etc/rc.local
```

### Step 4: Start It The First Time
```bash
cd /root/scripts
./server-manager.sh start
```

---

## 🎮 Daily Commands (What Your Friend Can Do)

### Check If Everything Is Working
```bash
cd /root/scripts
./server-manager.sh status
```
**What this shows:** Server status, how much RAM it's using, if auto-restart is running, etc.

### View The Server Console (See Chat, Commands)
```bash
screen -r mcserver
```
**To get out:** Press `Ctrl+A` then press `D` (this doesn't stop the server!)

### Send Commands To The Server
```bash
cd /root/scripts
./server-manager.sh send "time set day"
./server-manager.sh send "weather clear"
./server-manager.sh send "say Hello players!"
```

### See Who's Online
```bash
cd /root/scripts
./server-manager.sh players
```

### Restart The Server Right Now
```bash
cd /root/scripts
./server-manager.sh restart
```

### Stop Everything (Emergency)
```bash
cd /root/scripts
./server-manager.sh stop
```

### Create A Backup Right Now
```bash
cd /root/scripts
./backup.sh create manual
```

### See All Available Backups
```bash
cd /root/scripts
./backup.sh list
```

---

## 🔧 Common Settings To Change

### Change How Much RAM The Server Uses
Edit `/root/scripts/config.sh`:
```bash
MIN_RAM="4G"    # Start with 4GB
MAX_RAM="8G"    # Max 8GB
```

### Change How Often The Server Restarts
Edit `/root/scripts/config.sh`:
```bash
# Every 2 hours (7200 seconds)
RESTART_INTERVAL=7200

# Every 6 hours (21600 seconds)  
RESTART_INTERVAL=21600

# Every 8 hours (28800 seconds)
RESTART_INTERVAL=28800
```

### Change Restart Warnings
Edit `/root/scripts/config.sh`:
```bash
# More warnings (15min, 10min, 5min, 1min, 30sec)
WARN_TIMES=(900 600 300 60 30)

# Fewer warnings (just 5min and 30sec)
WARN_TIMES=(300 30)

# Just one warning (1 minute)
WARN_TIMES=(60)
```

### Change Backup Frequency
Edit `/root/scripts/config.sh`:
```bash
# Backup every 3 hours
BACKUP_INTERVAL=10800

# Backup every 12 hours  
BACKUP_INTERVAL=43200

# Keep more backups (10 instead of 7)
BACKUP_RETENTION=10
```

---

## 🔍 What's Running In The Background?

When your container starts, these "screen sessions" run in the background:

| Screen Name | What It Does | How To View It |
|-------------|--------------|----------------|
| `mcserver` | **Your Minecraft server** - this is where players connect | `screen -r mcserver` |
| `mcrestart` | **Auto-restart manager** - warns players and restarts server | `screen -r mcrestart` |
| `mcmonitor` | **Performance monitor** - watches CPU/RAM usage | `screen -r mcmonitor` |
| `mcbackup` | **Backup system** - creates automatic backups | `screen -r mcbackup` |

**To exit any screen:** Press `Ctrl+A` then press `D`

### See All Running Screens
```bash
screen -list
```

---

## 🆘 Troubleshooting For Beginners

### "Server won't start!"
```bash
# Check if your jar file exists
ls -la /root/SERVER/fabric.jar

# Check what the error is
cd /root/scripts
./server-manager.sh status

# Look at recent errors
./server-manager.sh logs server
```

### "I can't see the server console!"
```bash
# Try this:
screen -r mcserver

# If that doesn't work:
screen -list
# Then use the exact name from the list
```

### "Screen session is broken!"
```bash
# Clean up broken sessions
screen -wipe

# Restart everything
cd /root/scripts
./server-manager.sh stop
sleep 5
./server-manager.sh start
```

### "Server is using too much RAM!"
Edit `/root/scripts/config.sh` and lower these numbers:
```bash
MIN_RAM="4G"    # Was 6G, now 4G
MAX_RAM="6G"    # Was 8G, now 6G
```

### "Players complain about too many restarts!"
Edit `/root/scripts/config.sh`:
```bash
# Change from 4 hours to 8 hours
RESTART_INTERVAL=28800
```

---

## 📊 Understanding The Logs

### View Recent Activity
```bash
cd /root/scripts

# See everything
./server-manager.sh logs all

# Just server logs
./server-manager.sh logs server

# Just restart logs  
./server-manager.sh logs restart
```

### Log Files Location
- **Server operations:** `/root/scripts/logs/server.log`
- **Restart events:** `/root/scripts/logs/restart.log`
- **Performance data:** `/root/scripts/logs/monitor.log`
- **Backup operations:** `/root/scripts/logs/backup.log`

---

## 📅 What Happens Automatically

### When Your LXC Container Starts:
1. **Waits 10 seconds** for system to be ready
2. **Cleans up** any old broken screen sessions
3. **Starts the Minecraft server** in background
4. **Starts the auto-restart manager** in background
5. **Starts performance monitoring** in background
6. **Starts backup system** in background

### Every Few Hours (Based on Your Settings):
1. **Warns players** at your configured times (default: 10min, 5min, 1min, 30sec, 10sec)
2. **Saves the world** to disk
3. **Stops the server** gracefully
4. **Starts the server** again
5. **Tells players** the server is back online

### Every 6 Hours (Default):
1. **Forces a world save**
2. **Creates a compressed backup** of your entire server
3. **Removes old backups** (keeps newest 7 by default)

### Every 30 Seconds:
1. **Checks server performance** (CPU, RAM, disk)
2. **Logs statistics** to files
3. **Alerts if problems** detected (high CPU, low disk space, etc.)

---

## 🎯 Quick Reference Card

**Print this out and keep it handy!**

```bash
# Essential Commands (run from /root/scripts/)
./server-manager.sh status          # Check everything
./server-manager.sh restart         # Restart server now
./server-manager.sh stop            # Emergency stop
./server-manager.sh send "command"  # Send server command

# View Live Screens
screen -r mcserver     # Server console (Ctrl+A, D to exit)
screen -r mcmonitor    # Performance monitor
screen -list           # Show all screens

# Backups
./backup.sh create manual    # Backup now
./backup.sh list            # See all backups
./backup.sh stats           # Backup statistics

# Settings File
nano /root/scripts/config.sh    # Edit all settings
```

**Remember:** Always press `Ctrl+A` then `D` to exit screen sessions safely!

---

This system is designed to "just work" once set up. Your friend should only need the daily commands section for normal use!
