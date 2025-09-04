#!/bin/bash
# debug-screen-session.sh - Debug what happens in the screen session

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "=== Debug Screen Session Startup ==="
echo "This will show exactly what happens when the server starts in screen"
echo

# Clean up any existing sessions
if screen_exists "$SERVER_SCREEN"; then
    echo "Cleaning up existing screen session..."
    screen -S "$SERVER_SCREEN" -X quit
    sleep 2
fi

echo "Starting server with debug output..."
cd "$SERVER_DIR" || exit 1

# Create the screen session with more detailed logging
screen -dmS "$SERVER_SCREEN" bash -c "
    echo '=== Screen Session Debug Log ==='
    echo 'Time: $(date)'
    echo 'Directory: $(pwd)'
    echo 'User: $(whoami)'
    echo 'Java version:'
    java -version
    echo '================================='
    echo 'Starting Minecraft Server...'
    echo 'Command: java -Xms$MIN_RAM -Xmx$MAX_RAM $JAVA_OPTS -jar $JAR_NAME nogui'
    echo '================================='
    
    # Capture both stdout and stderr
    java -Xms$MIN_RAM -Xmx$MAX_RAM $JAVA_OPTS -jar '$JAR_NAME' nogui 2>&1
    
    echo '================================='
    echo 'Java process ended at: $(date)'
    echo 'Exit code: $?'
    echo 'Press any key to close this screen...'
    read
"

echo "Screen session created. Checking status..."

# Monitor the screen session
for i in {1..30}; do
    if screen_exists "$SERVER_SCREEN"; then
        echo "[$i] Screen session still exists"
        
        # Check if Java process is running
        if pgrep -f "$JAR_NAME" > /dev/null; then
            echo "[$i] Java process is running"
        else
            echo "[$i] Java process is NOT running"
        fi
        
        sleep 2
    else
        echo "[$i] Screen session has disappeared!"
        break
    fi
done

echo
echo "Final status:"
echo "Screen exists: $(screen_exists "$SERVER_SCREEN" && echo "YES" || echo "NO")"
echo "Java running: $(pgrep -f "$JAR_NAME" > /dev/null && echo "YES" || echo "NO")"

if screen_exists "$SERVER_SCREEN"; then
    echo
    echo "Screen session is still running. To view it:"
    echo "  screen -r $SERVER_SCREEN"
    echo
    echo "To see the current content:"
    screen -S "$SERVER_SCREEN" -X hardcopy /tmp/debug_screen_content.txt
    if [ -f /tmp/debug_screen_content.txt ]; then
        echo "Current screen content:"
        echo "========================"
        cat /tmp/debug_screen_content.txt
        echo "========================"
        rm -f /tmp/debug_screen_content.txt
    fi
fi
