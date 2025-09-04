#!/bin/bash
# start-with-management.sh

SERVER_SCREEN="mcserver"
RESTART_SCREEN="mcrestart"

# Kill old screens if they exist
for S in "$SERVER_SCREEN" "$RESTART_SCREEN"; do
    if screen -list | grep -q "$S"; then
        echo "[WARN] Killing old screen $S"
        screen -S "$S" -X quit
        sleep 1
    fi
done

# Start Minecraft server in its own screen
screen -DmS "$SERVER_SCREEN" /root/scripts/start.sh

# Start restart manager in its own screen
screen -DmS "$RESTART_SCREEN" /root/scripts/mc-auto-restart.sh

echo "[INFO] Screens started: $SERVER_SCREEN and $RESTART_SCREEN"
