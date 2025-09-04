# 🚨 Troubleshooting Guide - Service Won't Start

## Common Startup Issues & Solutions

### Issue 1: "Failed to start Minecraft Server!"

This is the most common issue. The service starts but the Minecraft server component fails.

#### **Quick Diagnosis:**
```bash
# Use our debug script first
cd /root/scripts
./debug-server-start.sh

# Manual checks
ls -la /root/scripts/
ls -la /root/SERVER/

# Check if jar file exists
ls -la /root/SERVER/*.jar

# Check server controller directly
cd /root/scripts
./server-controller.sh status
```

#### **Solution Steps:**

**Step 1: Run Debug Script**
```bash
cd /root/scripts
./debug-server-start.sh
```
This will check all components and show exactly what's missing or misconfigured.

**Step 2: Create Missing Directories**
```bash
sudo mkdir -p /root/scripts
sudo mkdir -p /root/SERVER
```

**Step 3: Check Script Files**
```bash
cd /root/scripts
ls -la

# Should show these files:
# config.sh, server-manager.sh, server-controller.sh, etc.
# If missing, copy them from your repository
```

**Step 4: Check Minecraft Server Files**
```bash
cd /root/SERVER
ls -la

# Should show:
# fabric.jar (or your server jar)
# mods/, world/, server.properties, etc.
# If missing, copy your Minecraft server files here
```

**Step 4: Fix config.sh Settings**
```bash
cd /root/scripts
nano config.sh

# Check these lines:
JAR_NAME="fabric.jar"     # Must match your actual jar file name
MIN_RAM="6G"              # Adjust for your container's memory
MAX_RAM="8G"              # Adjust for your container's memory
```

**Step 5: Test Manual Start**
```bash
cd /root/scripts
./server-controller.sh start

# If this works, then systemd should work too
```

---

### Issue 2: Scripts Not Found

```bash
# Error: /root/scripts/start-with-management.sh not found

# Solution: Copy scripts to correct location
sudo cp -r /path/to/your/scripts/* /root/scripts/
sudo chmod +x /root/scripts/*.sh
```

---

### Issue 3: Permission Issues

```bash
# Fix all permissions
sudo chown -R root:root /root/scripts/
sudo chmod +x /root/scripts/*.sh
sudo chown -R root:root /root/SERVER/
```

---

### Issue 4: Memory/Java Issues

```bash
# Check available memory
free -h

# Edit config.sh to use less RAM
cd /root/scripts
nano config.sh

# Change to lower values:
MIN_RAM="2G"
MAX_RAM="4G"
```

---

### Issue 5: Port Already in Use

```bash
# Check if port 25565 is in use
sudo netstat -tlnp | grep 25565

# Kill any existing Minecraft processes
sudo pkill -f minecraft
sudo pkill -f fabric
sudo pkill java
```

---

## 🔧 Step-by-Step Fix for Your Current Issue

Based on your logs, here's the exact fix:

### 1. Stop the failing service
```bash
sudo systemctl stop minecraft-server.service
```

### 2. Check what's missing
```bash
# Check directories
ls -la /root/scripts/
ls -la /root/SERVER/

# Check specific files
ls -la /root/scripts/config.sh
ls -la /root/SERVER/fabric.jar  # Or whatever your jar is called
```

### 3. Copy missing files
```bash
# If scripts are missing:
# Copy your scripts from wherever you downloaded them to /root/scripts/

# If SERVER directory is missing:
sudo mkdir -p /root/SERVER
# Copy your Minecraft server files (jar, mods, world, etc.) to /root/SERVER/
```

### 4. Fix permissions
```bash
sudo chown -R root:root /root/scripts/ /root/SERVER/
sudo chmod +x /root/scripts/*.sh
```

### 5. Test manually first
```bash
cd /root/scripts
./server-controller.sh start

# If this works, continue to step 6
# If this fails, check the error message and fix the issue
```

### 6. Fix config.sh if needed
```bash
cd /root/scripts
nano config.sh

# Make sure these match your setup:
JAR_NAME="fabric.jar"  # Change to your actual jar name
MIN_RAM="4G"           # Adjust for your container
MAX_RAM="6G"           # Adjust for your container
```

### 7. Test the full system
```bash
cd /root/scripts
./server-manager.sh start

# If this works, try systemd again
```

### 8. Restart systemd service
```bash
sudo systemctl start minecraft-server.service
sudo systemctl status minecraft-server.service
```

---

## 🔍 Detailed Diagnostics

### Check Service Logs
```bash
# Real-time logs
sudo journalctl -u minecraft-server.service -f

# Recent logs
sudo journalctl -u minecraft-server.service -n 50

# Logs since last restart
sudo journalctl -u minecraft-server.service --since "10 minutes ago"
```

### Check Application Logs
```bash
cd /root/scripts

# Check if logs directory exists
ls -la logs/

# View specific logs
tail -f logs/server.log
tail -f logs/manager.log
```

### Check Screen Sessions
```bash
# List all screen sessions
screen -list

# If you see orphaned sessions, clean them up
screen -wipe
```

### Check Java Installation
```bash
# Make sure Java is installed
java -version

# If not installed:
sudo apt update
sudo apt install openjdk-17-jre-headless
```

---

## 🎯 Most Likely Solutions

**90% of issues are one of these:**

1. **Missing `/root/SERVER/` directory or jar file**
   ```bash
   sudo mkdir -p /root/SERVER
   # Copy your fabric.jar and other server files here
   ```

2. **Wrong jar filename in config.sh**
   ```bash
   cd /root/scripts
   nano config.sh
   # Change JAR_NAME to match your actual file
   ```

3. **Not enough memory allocated**
   ```bash
   cd /root/scripts
   nano config.sh
   # Lower MIN_RAM and MAX_RAM values
   ```

4. **Scripts not copied to `/root/scripts/`**
   ```bash
   # Copy all your scripts to /root/scripts/
   sudo chmod +x /root/scripts/*.sh
   ```

---

## ✅ Verification Checklist

Before trying systemd again, verify:

- [ ] `/root/scripts/` exists with all script files
- [ ] `/root/SERVER/` exists with Minecraft server files  
- [ ] `config.sh` has correct jar filename and memory settings
- [ ] `./server-controller.sh start` works manually
- [ ] `./server-manager.sh start` works manually
- [ ] Java is installed and working
- [ ] Port 25565 is not already in use

Once all these check out, systemd should work perfectly! 🚀
