#!/bin/bash
# mc-auto-restart.sh - Minecraft auto-restart manager

# ================= Configuration =================
SCREEN_NAME="mcserver"
RESTART_INTERVAL_MINUTES=240  # default restart every 60 min
NOTIFICATIONS=(              # default notifications
  "600:Server will restart in 10 minutes!"
  "300:Server will restart in 5 minutes!"
  "60:Server will restart in 1 minute!"
  "10:Server will restart in 10 seconds!"
)

# ================= Helper Functions =================
usage() {
    echo "Usage: $0 [-t minutes] [-n \"time:msg ...\"]"
    echo ""
    echo "  -t    Restart interval in minutes (default: 60)"
    echo "  -n    Notification array in format 'seconds:message ...'"
    echo "        Example: -n \"600:'10 minutes left!' 300:'5 minutes!'\""
    exit 1
}

say() {
    screen -S "$SCREEN_NAME" -p 0 -X stuff "say $1$(printf \\r)"
}

# ================= Parse Options =================
while getopts "t:n:h" opt; do
    case "$opt" in
        t) RESTART_INTERVAL_MINUTES="$OPTARG" ;;
        n) IFS=' ' read -r -a NOTIFICATIONS <<< "$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# ================= Ensure screen session exists =================
if ! screen -list | grep -q "$SCREEN_NAME"; then
    echo "[INFO] Starting new screen session: $SCREEN_NAME"
    screen -dmS "$SCREEN_NAME" ./start.sh
    sleep 5  # wait for server to initialize
fi

# ================= Main Loop =================
RESTART_INTERVAL=$((RESTART_INTERVAL_MINUTES * 60))

while true; do
    echo "[INFO] Restart scheduled in $RESTART_INTERVAL_MINUTES minutes."

    # Go to sleep, but wake up for notifications
    for notif in "${NOTIFICATIONS[@]}"; do
        SECS=${notif%%:*}
        MSG=${notif#*:}
        SLEEP_TIME=$((RESTART_INTERVAL - SECS))
        if (( SLEEP_TIME > 0 )); then
            sleep "$SLEEP_TIME"
            say "$MSG"
        fi
    done

    # Final wait until restart
    sleep 5
    say "Restarting now..."
    sleep 5

    # Stop server gracefully
    screen -S "$SCREEN_NAME" -p 0 -X stuff "stop$(printf \\r)"
    sleep 15

    # Relaunch server (assumes start.sh exists)
    echo "[INFO] Restarting server..."
    screen -S "$SCREEN_NAME" -d -m ./start.sh
done
