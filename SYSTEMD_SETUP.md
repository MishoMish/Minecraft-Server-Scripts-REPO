# 🔧 Systemd Service Setup Guide

## Why Use Systemd Instead of rc.local?

✅ **Better process management** - systemd properly tracks the service  
✅ **Automatic restart** - Can restart if the service fails  
✅ **Proper logging** - Integrates with system logs  
✅ **Dependency management** - Waits for network, etc.  
✅ **Easy control** - Use `systemctl` commands  

## 📝 Improved Service File

Create `/etc/systemd/system/minecraft-server.service`:

```ini
[Unit]
Description=Minecraft Server Management Platform
Documentation=file:///root/scripts/BEGINNER_GUIDE.md
After=network-online.target
Wants=network-online.target
RequiresMountsFor=/root

[Service]
Type=forking
RemainAfterExit=yes
User=root
Group=root
WorkingDirectory=/root/scripts

# Start the management platform
ExecStart=/root/scripts/start-with-management.sh

# Graceful stop all components
ExecStop=/bin/bash -c '/root/scripts/server-manager.sh stop || true'

# Reload configuration
ExecReload=/bin/bash -c '/root/scripts/server-manager.sh restart'

# Don't restart too quickly if it fails
RestartSec=30
Restart=on-failure

# Security settings
NoNewPrivileges=false
PrivateTmp=false

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=minecraft-server

# Timeout settings
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
```

## 📋 Key Improvements Over Your Version

| Your Version | Improved Version | Why Better |
|--------------|------------------|------------|
| `Type=oneshot` | `Type=forking` | Better for background processes |
| Manual screen kills | Uses `server-manager.sh stop` | Graceful shutdown of all components |
| Only stops 2 screens | Stops all 4 components properly | Includes monitor + backup |
| No restart policy | `Restart=on-failure` | Auto-restart if service crashes |
| No timeout limits | Proper timeout settings | Prevents hanging |
| No logging config | Journal logging | Better log integration |

## 🚀 Installation Steps

### 1. Create the Service File
```bash
# Create the service file
sudo nano /etc/systemd/system/minecraft-server.service

# Copy the improved service content above into the file
```

### 2. Enable and Start the Service
```bash
# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable the service to start on boot
sudo systemctl enable minecraft-server.service

# Start the service now
sudo systemctl start minecraft-server.service
```

### 3. Verify It's Working
```bash
# Check service status
sudo systemctl status minecraft-server.service

# Check if all screen sessions are running
screen -list

# Check server status
cd /root/scripts && ./server-manager.sh status
```

## 🎮 Daily Management Commands

### Service Control
```bash
# Check service status
sudo systemctl status minecraft-server

# Start the service
sudo systemctl start minecraft-server

# Stop the service  
sudo systemctl stop minecraft-server

# Restart the service
sudo systemctl restart minecraft-server

# View service logs
sudo journalctl -u minecraft-server -f
```

### Direct Management (Still Works!)
```bash
# These still work even with systemd
cd /root/scripts
./server-manager.sh status
./server-manager.sh restart
screen -r mcserver
```

## 📊 Monitoring with Systemd

### View Live Logs
```bash
# Service logs
sudo journalctl -u minecraft-server -f

# All minecraft-related logs
sudo journalctl -t minecraft-server -f

# Last 50 lines
sudo journalctl -u minecraft-server -n 50
```

### Check Service Health
```bash
# Detailed status
sudo systemctl status minecraft-server.service

# Is it enabled for boot?
sudo systemctl is-enabled minecraft-server.service

# Is it running?
sudo systemctl is-active minecraft-server.service
```

## 🔄 Integration with Your Management System

The systemd service works perfectly with your existing scripts:

```bash
# Systemd starts this:
/root/scripts/start-with-management.sh
    ↓
# Which runs this:
/root/scripts/server-manager.sh start
    ↓
# Which creates these screen sessions:
- mcserver (Minecraft server)
- mcrestart (Auto-restart manager)  
- mcmonitor (Performance monitor)
- mcbackup (Backup system)
```

## 🛠️ Troubleshooting

### Service Won't Start
```bash
# Check what went wrong
sudo systemctl status minecraft-server.service
sudo journalctl -u minecraft-server.service

# Check file permissions
ls -la /root/scripts/start-with-management.sh
chmod +x /root/scripts/*.sh
```

### Service Starts But Components Missing
```bash
# Check individual components
cd /root/scripts
./server-manager.sh status

# View component logs
./server-manager.sh logs all
```

### Remove Old rc.local Entry
```bash
# If you previously used rc.local, remove the old entry
sudo nano /etc/rc.local
# Remove the line: /root/scripts/start-with-management.sh
```

## 🎯 Best Practices

### Service Management
```bash
# Always use systemctl for service control
sudo systemctl start minecraft-server   # Good
/root/scripts/start-with-management.sh   # Don't do this when using systemd

# Use server-manager.sh for game management
cd /root/scripts
./server-manager.sh restart              # Good for restarting just the game
sudo systemctl restart minecraft-server  # Full service restart
```

### Log Management
```bash
# Service logs (systemd level)
sudo journalctl -u minecraft-server

# Application logs (game level)  
cd /root/scripts
./server-manager.sh logs all
```

## 🔐 Security Considerations

The service runs as root (required for your setup), but includes security settings:
- `NoNewPrivileges=false` - Allows privilege changes (needed for minecraft)
- `PrivateTmp=false` - Allows access to /tmp (needed for screen)
- Proper timeout settings prevent hanging

## ⚡ Quick Reference

**Essential systemctl commands:**
```bash
sudo systemctl start minecraft-server     # Start
sudo systemctl stop minecraft-server      # Stop  
sudo systemctl restart minecraft-server   # Restart
sudo systemctl status minecraft-server    # Status
sudo journalctl -u minecraft-server -f    # Live logs
```

**Your existing commands still work:**
```bash
cd /root/scripts
./server-manager.sh status               # Check game status
./server-manager.sh restart              # Restart game only
screen -r mcserver                       # View game console
```

---

This systemd approach is **much more professional** and **reliable** than rc.local! 🚀
