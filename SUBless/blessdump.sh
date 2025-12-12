#!/bin/bash

# Colors for better UI
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# Clear screen and show banner
clear
echo -e "${BLUE}================================${NC}"
echo -e "${CYAN}      AirBless Wi-Fi Dumper      ${NC}"
echo -e "${YELLOW}        By MrPirateXD          ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    echo -e "${YELLOW}Example: sudo $0${NC}"
    echo -e "${YELLOW}Press ENTER to exit...${NC}"
    read
    exit 1
fi

# Check if airodump-ng is installed
if ! command -v airodump-ng &> /dev/null; then
    echo -e "${RED}Error: airodump-ng is not installed${NC}"
    echo -e "${YELLOW}Install it using: sudo apt install aircrack-ng${NC}"
    echo -e "${YELLOW}Press ENTER to exit...${NC}"
    read
    exit 1
fi

# Check if airmon-ng is installed
if ! command -v airmon-ng &> /dev/null; then
    echo -e "${RED}Error: airmon-ng is not installed${NC}"
    echo -e "${YELLOW}Install it using: sudo apt install aircrack-ng${NC}"
    echo -e "${YELLOW}Press ENTER to exit...${NC}"
    read
    exit 1
fi

# Function to stop monitor mode on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping monitor mode...${NC}"
    sudo airmon-ng stop wlp2s0mon > /dev/null 2>&1
    echo -e "${GREEN}Monitor mode stopped${NC}"
    
    # Clean up temp directory if it exists
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    sleep 1
    clear
    exit 0
}

# Trap Ctrl+C and other exit signals
trap cleanup SIGINT SIGTERM EXIT

# Start monitor mode
echo -e "${CYAN}Starting monitor mode on wlp2s0...${NC}"
sudo airmon-ng start wlp2s0 > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Monitor mode started successfully (wlp2s0mon)${NC}"
    echo ""
else
    echo -e "${RED}Error: Failed to start monitor mode${NC}"
    echo -e "${YELLOW}Make sure wlp2s0 interface exists and is not in use${NC}"
    echo -e "${YELLOW}Press ENTER to exit...${NC}"
    read
    exit 1
fi

# Get the actual user's home directory (not root's)
ACTUAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
if [ -z "$ACTUAL_USER" ]; then
    ACTUAL_USER=$USER
fi
USER_HOME=$(eval echo ~$ACTUAL_USER)

# Define base directory in user's home
BASE_DIR="$USER_HOME/AirCrack"

# Create AirCrack directory if it doesn't exist
if [ ! -d "$BASE_DIR" ]; then
    mkdir -p "$BASE_DIR"
    echo -e "${GREEN}Created directory: $BASE_DIR${NC}"
fi

# Create temporary directory for scan results
TEMP_DIR="/tmp/airodump_scan_$$"
mkdir -p "$TEMP_DIR"
SCAN_FILE="$TEMP_DIR/scan"

# Step 1: Run airodump-ng in scan mode
echo -e "${CYAN}Starting WiFi scan...${NC}"
echo -e "${YELLOW}Press Ctrl+C when you see your target network${NC}"
echo ""

# Run airodump-ng and capture output
sudo airodump-ng -w "$SCAN_FILE" --output-format csv wlp2s0mon

# Wait a moment for files to be written
sleep 1

# Clear screen before showing results
clear

# Find the most recent CSV file
CSV_FILE=$(ls -t "$SCAN_FILE"*.csv 2>/dev/null | head -1)

if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Error: No scan data found${NC}"
    echo -e "${YELLOW}Make sure you pressed Ctrl+C after networks appeared${NC}"
    echo -e "${YELLOW}Press ENTER to exit...${NC}"
    read
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo""
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${CYAN}      AirBless Wi-Fi Dumper     ${NC}"
echo -e "${YELLOW}       By MrPirateXD          ${NC}"
echo -e "${BLUE}================================${NC}"

# Parse CSV and display networks
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Available Networks:${NC}"
echo -e "${BLUE}================================${NC}"

# Read and parse the CSV file
declare -a BSSIDS
declare -a CHANNELS
declare -a ESSIDS
declare -a POWERS

INDEX=0
IN_AP_SECTION=false

while IFS=, read -r bssid first_seen last_seen channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
    # Skip until we find the AP section
    if [[ "$bssid" == *"BSSID"* ]]; then
        IN_AP_SECTION=true
        continue
    fi
    
    # Stop when we reach client section
    if [[ "$bssid" == *"Station MAC"* ]]; then
        break
    fi
    
    # Process AP entries
    if [ "$IN_AP_SECTION" = true ] && [ ! -z "$bssid" ]; then
        # Clean up the values (remove spaces)
        bssid=$(echo "$bssid" | tr -d ' ')
        channel=$(echo "$channel" | tr -d ' ')
        power=$(echo "$power" | tr -d ' ')
        essid=$(echo "$essid" | tr -d ' ')
        
        # Skip if BSSID is invalid
        if [[ ! "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
            continue
        fi
        
        # Store values
        BSSIDS[$INDEX]="$bssid"
        CHANNELS[$INDEX]="$channel"
        ESSIDS[$INDEX]="$essid"
        POWERS[$INDEX]="$power"
        
        # Display network
        printf "${YELLOW}%2d.${NC} ${GREEN}%-17s${NC} | Ch: ${CYAN}%-3s${NC} | Power: ${BLUE}%-4s${NC} | ESSID: ${GREEN}%s${NC}\n" \
            "$((INDEX + 1))" "$bssid" "$channel" "$power" "$essid"
        
        INDEX=$((INDEX + 1))
    fi
done < "$CSV_FILE"

# Clean up temp files
rm -rf "$TEMP_DIR"

if [ $INDEX -eq 0 ]; then
    echo -e "${RED}No networks found. Make sure your wireless adapter is in monitor mode.${NC}"
    echo -e "${YELLOW}Press ENTER to exit...${NC}"
    read
    exit 1
fi

echo -e "${BLUE}================================${NC}"
echo ""

# Step 2: Ask user to select a network
while true; do
    echo -e "${YELLOW}Enter the serial number of the target network (1-$INDEX):${NC}"
    read -p "> " SELECTION
    
    # Check if input is empty
    if [ -z "$SELECTION" ]; then
        echo -e "${RED}Error: Input cannot be empty${NC}"
        echo ""
    # Check if input contains only numbers
    elif ! [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid command. Please enter only numbers${NC}"
        echo ""
    # Check if number is in valid range
    elif [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt $INDEX ]; then
        echo -e "${RED}Error: Number out of range. Please enter a number between 1 and $INDEX${NC}"
        echo ""
    else
        ARRAY_INDEX=$((SELECTION - 1))
        TARGET_BSSID="${BSSIDS[$ARRAY_INDEX]}"
        TARGET_CHANNEL="${CHANNELS[$ARRAY_INDEX]}"
        TARGET_ESSID="${ESSIDS[$ARRAY_INDEX]}"
        break
    fi
done

# Clear screen and show selected network
clear
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Selected Network:${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "  BSSID:   ${CYAN}$TARGET_BSSID${NC}"
echo -e "  Channel: ${CYAN}$TARGET_CHANNEL${NC}"
echo -e "  ESSID:   ${CYAN}$TARGET_ESSID${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Step 3: Prompt for filename
while true; do
    echo -e "${YELLOW}Enter filename for capture (without extension):${NC}"
    read -p "> " FILENAME
    
    if [ -z "$FILENAME" ]; then
        echo -e "${RED}Error: Filename cannot be empty${NC}"
        echo ""
    elif [[ "$FILENAME" =~ [[:space:]] ]]; then
        echo -e "${RED}Error: Filename cannot contain spaces${NC}"
        echo ""
    elif [[ "$FILENAME" =~ [^a-zA-Z0-9_-] ]]; then
        echo -e "${RED}Error: Filename contains invalid characters. Use only letters, numbers, hyphens, and underscores${NC}"
        echo ""
    else
        break
    fi
done

# Clear screen before directory check
clear

# Check if directory already exists
CAPTURE_DIR="$BASE_DIR/$FILENAME"

if [ -d "$CAPTURE_DIR" ]; then
    while true; do
        echo -e "${YELLOW}Warning: Directory '$FILENAME' already exists!${NC}"
        echo -e "${YELLOW}Do you want to delete the existing directory? (Yes/No or Y/N)${NC}"
        read -p "> " DELETE_CHOICE
        
        # Convert to lowercase for comparison
        DELETE_CHOICE=$(echo "$DELETE_CHOICE" | tr '[:upper:]' '[:lower:]')
        
        if [ "$DELETE_CHOICE" = "yes" ] || [ "$DELETE_CHOICE" = "y" ]; then
            rm -rf "$CAPTURE_DIR"
            echo -e "${GREEN}Deleted existing directory${NC}"
            mkdir -p "$CAPTURE_DIR"
            sleep 1
            break
        elif [ "$DELETE_CHOICE" = "no" ] || [ "$DELETE_CHOICE" = "n" ]; then
            # Find next available number
            COUNTER=1
            NEW_FILENAME="${FILENAME}${COUNTER}"
            CAPTURE_DIR="$BASE_DIR/$NEW_FILENAME"
            
            while [ -d "$CAPTURE_DIR" ]; do
                COUNTER=$((COUNTER + 1))
                NEW_FILENAME="${FILENAME}${COUNTER}"
                CAPTURE_DIR="$BASE_DIR/$NEW_FILENAME"
            done
            
            FILENAME="$NEW_FILENAME"
            mkdir -p "$CAPTURE_DIR"
            echo -e "${GREEN}Created new directory: $FILENAME${NC}"
            sleep 1
            break
        else
            echo -e "${RED}Error: Invalid input! Please enter Yes/No or Y/N${NC}"
            echo ""
        fi
    done
else
    mkdir -p "$CAPTURE_DIR"
fi

# Clear screen and show final summary
clear

echo -e "${GREEN}Capture files will be stored in: $CAPTURE_DIR${NC}"
echo ""

# Full path for capture files
FULL_PATH="$CAPTURE_DIR/$FILENAME"

# Display summary
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Capture Configuration:${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "Filename:    ${GREEN}$FILENAME${NC}"
echo -e "Directory:   ${GREEN}$CAPTURE_DIR${NC}"
echo -e "ESSID:       ${GREEN}$TARGET_ESSID${NC}"
echo -e "BSSID:       ${GREEN}$TARGET_BSSID${NC}"
echo -e "Channel:     ${GREEN}$TARGET_CHANNEL${NC}"
echo -e "Interface:   ${GREEN}wlp2s0mon${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Confirmation
echo -e "${YELLOW}Press ENTER to start capture, or Ctrl+C to cancel${NC}"
read

# Clear screen before starting capture
clear

# Run airodump-ng with selected target
echo -e "${GREEN}Starting targeted capture...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop capture${NC}"
echo ""

sudo airodump-ng -w "$FULL_PATH" -c "$TARGET_CHANNEL" --bssid "$TARGET_BSSID" wlp2s0mon

# After capture stops
echo ""
echo -e "${GREEN}Capture completed!${NC}"
echo -e "${BLUE}Files saved in: $CAPTURE_DIR${NC}"
ls -lh "$CAPTURE_DIR"
