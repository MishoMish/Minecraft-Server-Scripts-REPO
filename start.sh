#!/bin/bash
# start.sh - Flexible Fabric Minecraft Server Launcher

# ================= Configuration =================
# Default values (you can override with command-line options)
SERVER_DIR="$HOME/SERVER"
JAR_NAME="fabric.jar"
MIN_RAM="6G"
MAX_RAM="8G"
EXTRA_OPTS=""  # Any extra Java options you want to pass

# ================= Helper Functions =================
usage() {
    echo "Usage: $0 [-d server_dir] [-j jar_name] [-m min_ram] [-M max_ram] [-o extra_java_options]"
    echo ""
    echo "  -d    Server folder (default: ./SERVER)"
    echo "  -j    Jar file name (default: fabric.jar)"
    echo "  -m    Minimum RAM (default: 1G)"
    echo "  -M    Maximum RAM (default: 2G)"
    echo "  -o    Extra Java options (optional)"
    exit 1
}

# ================= Parse Options =================
while getopts "d:j:m:M:o:h" opt; do
    case "$opt" in
        d) SERVER_DIR="$OPTARG" ;;
        j) JAR_NAME="$OPTARG" ;;
        m) MIN_RAM="$OPTARG" ;;
        M) MAX_RAM="$OPTARG" ;;
        o) EXTRA_OPTS="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# ================= Launch Server =================
cd "$SERVER_DIR" || { echo "Error: Server directory '$SERVER_DIR' not found!"; exit 1; }

echo "Starting Minecraft Fabric Server..."
echo "Server folder: $SERVER_DIR"
echo "Jar file: $JAR_NAME"
echo "RAM: $MIN_RAM -> $MAX_RAM"
echo "Extra options: $EXTRA_OPTS"

# Run the server
java -Xms"$MIN_RAM" -Xmx"$MAX_RAM" $EXTRA_OPTS -jar "$JAR_NAME" nogui
