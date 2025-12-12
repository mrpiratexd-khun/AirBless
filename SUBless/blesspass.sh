#!/bin/bash

# Colors for better UI
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color

# Get the actual user's home directory (not root's)
ACTUAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
if [ -z "$ACTUAL_USER" ]; then
    ACTUAL_USER=$USER
fi
USER_HOME=$(eval echo ~$ACTUAL_USER)

# Define base directory in user's home
BASE_DIR="$USER_HOME/AirCrack"

#############################################
# WORDLIST DIRECTORY
# Users can place their wordlists here
#############################################
WORDLIST_DIR="$USER_HOME/GiveMeYourWordlist"
#############################################

# Clear screen and show banner
clear
echo -e "${BLUE}=====================================${NC}"
echo -e "${CYAN}      AirBless Password Cracker      ${NC}"
echo -e "${YELLOW}          By MrPirateXD            ${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    echo -e "${YELLOW}Example: sudo $0${NC}"
    echo -e "${YELLOW}Press ENTER to exit...${NC}"
    read
    exit 1
fi

# Check if aircrack-ng is installed
if ! command -v aircrack-ng &> /dev/null; then
    echo -e "${RED}Error: aircrack-ng is not installed${NC}"
    echo -e "${YELLOW}Install it using: sudo apt install aircrack-ng${NC}"
    echo -e "${YELLOW}Press ENTER to exit...${NC}"
    read
    exit 1
fi

# Step 1: Ask for wordlist choice
echo -e "${CYAN}Select wordlist option:${NC}"
echo -e "${YELLOW}1.${NC} Drag and drop your wordlist file"
echo -e "${YELLOW}2.${NC} Browse from GiveMeYourWordlist folder ${CYAN}(Place your .txt wordlists in ~/GiveMeYourWordlist)${NC}"
echo ""

while true; do
    echo -e "${YELLOW}Enter your choice (1/2):${NC}"
    read -p "> " WORDLIST_CHOICE
    
    if [ -z "$WORDLIST_CHOICE" ]; then
        echo -e "${RED}Error: Input cannot be empty${NC}"
        echo ""
    elif ! [[ "$WORDLIST_CHOICE" =~ ^[1-2]$ ]]; then
        echo -e "${RED}Error: Invalid choice. Please enter 1 or 2${NC}"
        echo ""
    else
        break
    fi
done

clear

WORDLIST_PATH=""

if [ "$WORDLIST_CHOICE" = "1" ]; then
    # Drag and drop wordlist
    while true; do
        echo -e "${YELLOW}Enter the full path to your wordlist file:${NC}"
        echo -e "${CYAN}(You can drag and drop the file here)${NC}"
        read -e -p "> " EXTERNAL_WORDLIST
        
        # Remove quotes and escape characters from drag-and-drop
        EXTERNAL_WORDLIST=$(echo "$EXTERNAL_WORDLIST" | sed "s/^['\"]//;s/['\"]$//;s/\\\\//g" | xargs)
        
        if [ -z "$EXTERNAL_WORDLIST" ]; then
            echo -e "${RED}Error: Path cannot be empty${NC}"
            echo ""
        elif [ ! -f "$EXTERNAL_WORDLIST" ]; then
            echo -e "${RED}Error: File not found: $EXTERNAL_WORDLIST${NC}"
            echo ""
        else
            WORDLIST_PATH="$EXTERNAL_WORDLIST"
            WORD_COUNT=$(wc -l < "$WORDLIST_PATH")
            echo -e "${GREEN}Wordlist loaded: $WORD_COUNT passwords${NC}"
            echo ""
            break
        fi
    done
    
elif [ "$WORDLIST_CHOICE" = "2" ]; then
    # Browse from GiveMeYourWordlist folder
    
    # Create directory if it doesn't exist
    if [ ! -d "$WORDLIST_DIR" ]; then
        mkdir -p "$WORDLIST_DIR"
        # Set proper ownership and permissions for the actual user
        chown "$ACTUAL_USER:$ACTUAL_USER" "$WORDLIST_DIR"
        chmod 755 "$WORDLIST_DIR"
        echo -e "${GREEN}Created directory: $WORDLIST_DIR${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}Wordlist Directory: ${GREEN}$WORDLIST_DIR${NC}"
    echo ""
    
    # Find all .txt files in the wordlist directory
    mapfile -t TXT_FILES < <(find "$WORDLIST_DIR" -maxdepth 1 -type f -name "*.txt" 2>/dev/null | sort)
    
    if [ ${#TXT_FILES[@]} -eq 0 ]; then
        echo -e "${RED}No wordlist files found in $WORDLIST_DIR${NC}"
        echo -e "${YELLOW}Please download or create some .txt wordlist files and place them in:${NC}"
        echo -e "${CYAN}$WORDLIST_DIR${NC}"
        echo ""
        echo -e "${YELLOW}Press ENTER to restart the script...${NC}"
        read
        clear
        exec "$0"
    fi
    
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${GREEN}Available Wordlists:${NC}"
    echo -e "${BLUE}=====================================${NC}"
    
    for i in "${!TXT_FILES[@]}"; do
        FILE_NAME=$(basename "${TXT_FILES[$i]}")
        FILE_SIZE=$(du -h "${TXT_FILES[$i]}" | cut -f1)
        FILE_LINES=$(wc -l < "${TXT_FILES[$i]}" 2>/dev/null | numfmt --grouping 2>/dev/null || wc -l < "${TXT_FILES[$i]}")
        printf "${YELLOW}%2d.${NC} ${GREEN}%-40s${NC}\n" "$((i + 1))" "$FILE_NAME"
        printf "    Size: ${CYAN}%-8s${NC} | Passwords: ${CYAN}%s${NC}\n" "$FILE_SIZE" "$FILE_LINES"
    done
    
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    
    while true; do
        echo -e "${YELLOW}Enter the serial number of the wordlist (1-${#TXT_FILES[@]}):${NC}"
        read -p "> " FILE_SELECTION
        
        if [ -z "$FILE_SELECTION" ]; then
            echo -e "${RED}Error: Input cannot be empty${NC}"
            echo ""
        elif ! [[ "$FILE_SELECTION" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Error: Invalid command. Please enter only numbers${NC}"
            echo ""
        elif [ "$FILE_SELECTION" -lt 1 ] || [ "$FILE_SELECTION" -gt ${#TXT_FILES[@]} ]; then
            echo -e "${RED}Error: Number out of range. Please enter between 1 and ${#TXT_FILES[@]}${NC}"
            echo ""
        else
            ARRAY_INDEX=$((FILE_SELECTION - 1))
            WORDLIST_PATH="${TXT_FILES[$ARRAY_INDEX]}"
            WORD_COUNT=$(wc -l < "$WORDLIST_PATH")
            echo -e "${GREEN}Wordlist loaded: $WORD_COUNT passwords${NC}"
            echo ""
            break
        fi
    done
fi

# Step 2: Ask for BSSID
echo -e "${YELLOW}Enter target BSSID (MAC address, e.g., AA:BB:CC:DD:EE:FF):${NC}"

while true; do
    read -p "> " BSSID
    
    if [ -z "$BSSID" ]; then
        echo -e "${RED}Error: BSSID cannot be empty${NC}"
        echo ""
    elif ! [[ "$BSSID" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        echo -e "${RED}Error: Invalid BSSID format. Use format: AA:BB:CC:DD:EE:FF${NC}"
        echo ""
    else
        break
    fi
done

clear

# Step 3: Ask for capture file
echo -e "${CYAN}Select capture file option:${NC}"
echo -e "${YELLOW}1.${NC} Browse from AirCrack directory ($BASE_DIR)"
echo -e "${YELLOW}2.${NC} Enter custom file path"
echo ""

while true; do
    echo -e "${YELLOW}Enter your choice (1/2):${NC}"
    read -p "> " FILE_CHOICE
    
    if [ -z "$FILE_CHOICE" ]; then
        echo -e "${RED}Error: Input cannot be empty${NC}"
        echo ""
    elif ! [[ "$FILE_CHOICE" =~ ^[1-2]$ ]]; then
        echo -e "${RED}Error: Invalid choice. Please enter 1 or 2${NC}"
        echo ""
    else
        break
    fi
done

clear

CAP_FILE=""

if [ "$FILE_CHOICE" = "1" ]; then
    # Browse AirCrack directory
    if [ ! -d "$BASE_DIR" ]; then
        echo -e "${RED}Error: AirCrack directory not found: $BASE_DIR${NC}"
        echo -e "${YELLOW}Press ENTER to exit...${NC}"
        read
        exit 1
    fi
    
    # Find all capture files
    mapfile -t CAP_FILES < <(find "$BASE_DIR" -type f \( -name "*.cap" -o -name "*.pcap" -o -name "*.pcapng" \) 2>/dev/null)
    
    if [ ${#CAP_FILES[@]} -eq 0 ]; then
        echo -e "${RED}Error: No capture files found in $BASE_DIR${NC}"
        echo -e "${YELLOW}Press ENTER to exit...${NC}"
        read
        exit 1
    fi
    
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${GREEN}Available Capture Files:${NC}"
    echo -e "${BLUE}=====================================${NC}"
    
    for i in "${!CAP_FILES[@]}"; do
        FILE_NAME=$(basename "${CAP_FILES[$i]}")
        FILE_SIZE=$(du -h "${CAP_FILES[$i]}" | cut -f1)
        printf "${YELLOW}%2d.${NC} ${GREEN}%-40s${NC} | Size: ${CYAN}%s${NC}\n" "$((i + 1))" "$FILE_NAME" "$FILE_SIZE"
    done
    
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    
    while true; do
        echo -e "${YELLOW}Enter the serial number of the capture file (1-${#CAP_FILES[@]}):${NC}"
        read -p "> " FILE_SELECTION
        
        if [ -z "$FILE_SELECTION" ]; then
            echo -e "${RED}Error: Input cannot be empty${NC}"
            echo ""
        elif ! [[ "$FILE_SELECTION" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Error: Invalid command. Please enter only numbers${NC}"
            echo ""
        elif [ "$FILE_SELECTION" -lt 1 ] || [ "$FILE_SELECTION" -gt ${#CAP_FILES[@]} ]; then
            echo -e "${RED}Error: Number out of range. Please enter between 1 and ${#CAP_FILES[@]}${NC}"
            echo ""
        else
            ARRAY_INDEX=$((FILE_SELECTION - 1))
            CAP_FILE="${CAP_FILES[$ARRAY_INDEX]}"
            break
        fi
    done
    
elif [ "$FILE_CHOICE" = "2" ]; then
    # Custom file path
    while true; do
        echo -e "${YELLOW}Enter the full path to your capture file:${NC}"
        echo -e "${CYAN}(You can drag and drop the file here)${NC}"
        read -e -p "> " CAP_FILE
        
        # Remove quotes and escape characters from drag-and-drop
        CAP_FILE=$(echo "$CAP_FILE" | sed "s/^['\"]//;s/['\"]$//;s/\\\\//g" | xargs)
        
        if [ -z "$CAP_FILE" ]; then
            echo -e "${RED}Error: Path cannot be empty${NC}"
            echo ""
        elif [ ! -f "$CAP_FILE" ]; then
            echo -e "${RED}Error: File not found: $CAP_FILE${NC}"
            echo ""
        else
            break
        fi
    done
fi

clear

# Display summary
echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}Cracking Configuration:${NC}"
echo -e "${BLUE}=====================================${NC}"
echo -e "Wordlist:     ${GREEN}$WORDLIST_PATH${NC}"
echo -e "BSSID:        ${GREEN}$BSSID${NC}"
echo -e "Capture File: ${GREEN}$CAP_FILE${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Confirmation
echo -e "${YELLOW}Press ENTER to start cracking, or Ctrl+C to cancel${NC}"
read

clear

# Run aircrack-ng
echo -e "${CYAN}Starting aircrack-ng...${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

sudo aircrack-ng -w "$WORDLIST_PATH" -b "$BSSID" "$CAP_FILE"

echo ""
echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}     Exiting Cracking Process       ${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "${YELLOW}Press ENTER to exit...${NC}"
read
clear
