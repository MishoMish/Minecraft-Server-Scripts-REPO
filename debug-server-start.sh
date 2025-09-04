#!/bin/bash
# debug-server-start.sh - Debug script to test Minecraft server startup

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "=== Debug Server Startup ==="
echo "Script Directory: $SCRIPT_DIR"
echo "Server Directory: $SERVER_DIR"
echo "JAR Name: $JAR_NAME"
echo "Min RAM: $MIN_RAM"
echo "Max RAM: $MAX_RAM"
echo "Screen Name: $SERVER_SCREEN"
echo

# Check if server directory exists
echo "Checking server directory..."
if [ ! -d "$SERVER_DIR" ]; then
    echo "❌ Error: Server directory '$SERVER_DIR' not found!"
    exit 1
else
    echo "✅ Server directory exists"
fi

# Check if jar file exists
echo "Checking jar file..."
if [ ! -f "$SERVER_DIR/$JAR_NAME" ]; then
    echo "❌ Error: Server jar '$SERVER_DIR/$JAR_NAME' not found!"
    exit 1
else
    echo "✅ JAR file exists: $(ls -lh "$SERVER_DIR/$JAR_NAME")"
fi

# Check Java installation
echo "Checking Java..."
if ! command -v java &> /dev/null; then
    echo "❌ Error: Java not found!"
    exit 1
else
    echo "✅ Java found: $(java -version 2>&1 | head -n1)"
fi

# Check screen command
echo "Checking screen..."
if ! command -v screen &> /dev/null; then
    echo "❌ Error: Screen not found!"
    exit 1
else
    echo "✅ Screen found: $(screen -version)"
fi

# Test if we can change to server directory
echo "Testing directory access..."
cd "$SERVER_DIR" || {
    echo "❌ Error: Cannot access server directory!"
    exit 1
}
echo "✅ Successfully changed to server directory"
echo "Current directory: $(pwd)"
echo "Directory contents:"
ls -la | head -10

# Test Java with the jar file (dry run)
echo
echo "Testing Java execution (dry run)..."
echo "Command that would be executed:"
echo "java -Xms$MIN_RAM -Xmx$MAX_RAM $JAVA_OPTS -jar '$JAR_NAME' nogui"

# Test if we can create a simple screen session
echo
echo "Testing screen session creation..."
screen -dmS "test-session" bash -c "echo 'Test session created'; sleep 2"
sleep 1

if screen -list | grep -q "test-session"; then
    echo "✅ Screen session created successfully"
    screen -S "test-session" -X quit
    echo "✅ Screen session cleaned up"
else
    echo "❌ Failed to create screen session"
fi

echo
echo "=== Debug Complete ==="
echo "If all checks passed, the issue might be with the Java execution or server startup process."
echo "Try running the server manually with:"
echo "cd $SERVER_DIR && java -Xms$MIN_RAM -Xmx$MAX_RAM $JAVA_OPTS -jar '$JAR_NAME' nogui"
