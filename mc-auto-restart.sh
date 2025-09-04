#!/bin/bash
# mc-auto-restart.sh
# Automatic Minecraft server restart script using screen

# ---------------- CONFIG ----------------
SCREEN_NAME="mc_server"       # Name of the screen session
SERVER_START="./start.sh"     # Your Minecraft server start script
RESTART_INTERVAL=3600         # Seconds between automatic restarts (1h = 3600s)
WARN_TIME=60                  # Seconds before restart to warn players
# ---------------------------------------

# Function to start the screen session
start_screen() {
    if ! screen -list | grep -q "$SCREEN_NAME"; then
        echo "[INFO] Starting new screen session: $SCREEN_NAME"
        screen -dmS "$SCREEN_NAME" $SERVER_START
        sleep 5  # wait for server to initialize
    else
        echo "[INFO] Screen session '$SCREEN_NAME' already running."
    fi
}

# Function to send a command to the Minecraft server
send_cmd() {
    local cmd="$1"
    screen -S "$SCREEN_NAME" -X stuff "$cmd$(printf \\r)"
}

# Start the server in screen if not running
start_screen

# Main loop: repeat forever
while true; do
    echo "[INFO] Next restart in $RESTART_INTERVAL seconds."
    sleep $((RESTART_INTERVAL - WARN_TIME))

    # Warn players
    echo "[INFO] Sending restart warning..."
    send_cmd "say Server will restart in $WARN_TIME seconds!"

    sleep $WARN_TIME

    # Save and stop server
    echo "[INFO] Saving and stopping server..."
    send_cmd "save-all"
    sleep 5
    send_cmd "stop"

    # Wait for server to stop fully
    sleep 10

    # Restart server
    echo "[INFO] Restarting server..."
    start_screen

    echo "[INFO] Server restarted successfully."
done
