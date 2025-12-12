#!/bin/bash

# Colors for better UI
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBLESS_DIR="$SCRIPT_DIR/SUBless"

# Clear screen function
clear_screen() {
    clear
}

# Trap Ctrl+C to clear screen before exit
trap 'clear_screen; exit 0' INT TERM

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check AirCrack-ng and dependencies
check_aircrack() {
    clear_screen
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}   Checking AirCrack-ng Dependencies${NC}"
    echo -e "${BLUE}======================================${NC}\n"
    
    local missing=()
    
    # Check for aircrack-ng suite tools
    local tools=("aircrack-ng" "airodump-ng" "aireplay-ng" "airmon-ng")
    
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            echo -e "${GREEN}✓${NC} $tool is installed"
        else
            echo -e "${RED}✗${NC} $tool is NOT installed"
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -eq 0 ]; then
        echo -e "\n${GREEN}All required dependencies are installed!${NC}\n"
        return 0
    else
        echo -e "\n${RED}Missing dependencies detected!${NC}\n"
        return 1
    fi
}

# Function to install AirCrack-ng
install_aircrack() {
    clear_screen
    echo -e "${YELLOW}Installing AirCrack-ng and dependencies...${NC}\n"
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Installation requires root privileges!${NC}"
        echo -e "${YELLOW}Please run: sudo $0${NC}\n"
        read -p "Press Enter to continue..."
        return 1
    fi
    
    # Detect package manager
    if command_exists apt-get; then
        apt-get update
        apt-get install -y aircrack-ng
    elif command_exists yum; then
        yum install -y aircrack-ng
    elif command_exists pacman; then
        pacman -Sy --noconfirm aircrack-ng
    else
        echo -e "${RED}Unable to detect package manager!${NC}"
        echo -e "${YELLOW}Please install aircrack-ng manually.${NC}\n"
        read -p "Press Enter to continue..."
        return 1
    fi
    
    echo -e "\n${GREEN}Installation complete!${NC}\n"
    read -p "Press Enter to continue..."
}

# Function to check if required scripts exist
check_scripts() {
    local all_exist=true
    
    if [ ! -f "$SUBLESS_DIR/blessdump.sh" ]; then
        echo -e "${RED}✗${NC} blessdump.sh not found in SUBless folder"
        all_exist=false
    fi
    
    if [ ! -f "$SUBLESS_DIR/blessdeauth.sh" ]; then
        echo -e "${RED}✗${NC} blessdeauth.sh not found in SUBless folder"
        all_exist=false
    fi
    
    if [ ! -f "$SUBLESS_DIR/blesspass.sh" ]; then
        echo -e "${RED}✗${NC} blesspass.sh not found in SUBless folder"
        all_exist=false
    fi
    
    if [ "$all_exist" = false ]; then
        echo -e "\n${YELLOW}Please ensure all scripts are in: $SUBLESS_DIR${NC}\n"
        return 1
    fi
    
    return 0
}

# Function to display main menu
show_menu() {
    clear_screen
    echo -e "${BLUE}======================================${NC}"
    echo -e "${CYAN}         AirBless SuperScript         ${NC}"
    echo -e "${GREEN}      SubScript Of AirCrack-ng       ${NC}"
    echo -e "${YELLOW}         Made By MrPirateXD         ${NC}"
    echo -e "${BLUE}======================================${NC}\n"
    echo -e "${GREEN}1.${GREEN} AirBless-DUMP"
    echo -e "${GREEN}2.${RED} AirBless-Deauth"
    echo -e "${GREEN}3.${CYAN} AirBless-Password-Cracker"
    echo -e "${GREEN}0.${NC} Exit\n"
    echo -e "${BLUE}======================================${NC}"
}

# Function to run selected tool
run_tool() {
    local choice=$1
    clear_screen
    
    case $choice in
        1)
            if [ -f "$SUBLESS_DIR/blessdump.sh" ]; then
                echo -e "${GREEN}Running AirBless-DUMP...${NC}\n"
                sudo bash "$SUBLESS_DIR/blessdump.sh"
            else
                echo -e "${RED}Error: blessdump.sh not found!${NC}\n"
            fi
            ;;
        2)
            if [ -f "$SUBLESS_DIR/blessdeauth.sh" ]; then
                echo -e "${GREEN}Running AirBless-Deauth...${NC}\n"
                sudo bash "$SUBLESS_DIR/blessdeauth.sh"
            else
                echo -e "${RED}Error: blessdeauth.sh not found!${NC}\n"
            fi
            ;;
        3)
            if [ -f "$SUBLESS_DIR/blesspass.sh" ]; then
                echo -e "${GREEN}Running AirBless-Password-Cracker...${NC}\n"
                sudo bash "$SUBLESS_DIR/blesspass.sh"
            else
                echo -e "${RED}Error: blesspass.sh not found!${NC}\n"
            fi
            ;;
        0)
            clear_screen
            echo -e "${GREEN}Exiting AirBless Manager...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Invalid option '$choice'!${NC}"
            echo -e "${YELLOW}Please enter a number between 0-3${NC}\n"
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Function to check if initial scan was done
check_initial_scan() {
    local flag_file="$SCRIPT_DIR/.aircrack_checked"
    
    if [ -f "$flag_file" ]; then
        return 1  # Already scanned
    else
        return 0  # First run
    fi
}

# Function to mark initial scan as done
mark_scan_done() {
    local flag_file="$SCRIPT_DIR/.aircrack_checked"
    touch "$flag_file"
}

# Function to verify if aircrack is installed (silent check)
verify_aircrack_installed() {
    local tools=("aircrack-ng" "airodump-ng" "aireplay-ng" "airmon-ng")
    
    for tool in "${tools[@]}"; do
        if ! command_exists "$tool"; then
            return 1  # Not all tools are installed
        fi
    done
    
    return 0  # All tools installed
}

# Main execution
main() {
    # Check if SUBless directory exists
    if [ ! -d "$SUBLESS_DIR" ]; then
        clear_screen
        echo -e "${RED}SUBless directory not found!${NC}"
        echo -e "${YELLOW}Creating SUBless directory at: $SUBLESS_DIR${NC}\n"
        mkdir -p "$SUBLESS_DIR"
        echo -e "${YELLOW}Please place your scripts (blessdump.sh, blessdeauth.sh, blesspass.sh) in this directory.${NC}\n"
        read -p "Press Enter to continue..."
    fi
    
    # Check if this is first run or if aircrack is missing
    if check_initial_scan; then
        # First run - always scan
        if ! check_aircrack; then
            echo -e "${YELLOW}Would you like to install AirCrack-ng now? (y/n)${NC}"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                install_aircrack
            fi
        fi
        mark_scan_done
    else
        # Not first run - check silently if aircrack is missing
        if ! verify_aircrack_installed; then
            # Aircrack was deleted/missing - show scan
            if ! check_aircrack; then
                echo -e "${YELLOW}Would you like to install AirCrack-ng now? (y/n)${NC}"
                read -r response
                if [[ "$response" =~ ^[Yy]$ ]]; then
                    install_aircrack
                fi
            fi
        fi
    fi
    
    # Main loop
    while true; do
        show_menu
        read -p "Enter your choice: " choice
        run_tool "$choice"
    done
}

# Run main function
main
