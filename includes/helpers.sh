# includes/helpers.sh
#!/bin/bash

# Helper functions for logging and error handling

RESET=$(tput sgr0)
BOLD=$(tput bold)
REVERSE=$(tput rev)
FG_BLUE=$(tput setaf 4)
FG_GREEN=$(tput setaf 2)
FG_RED=$(tput setaf 1)
FG_YELLOW=$(tput setaf 3)
FG_CYAN=$(tput setaf 6)
FG_MAGENTA=$(tput setaf 5)
FG_ORANGE=$(tput setaf 214)
FG_PURPLE=$(tput setaf 5)
FG_WHITE=$(tput setaf 7)

# Check if terminal supports UTF-8 and set symbols accordingly
if [[ "$LANG" == *"UTF-8"* ]] || [[ "$LC_ALL" == *"UTF-8"* ]]; then
    CHECKMARK="✓"
    CROSSMARK="✗"
    BULLET="•"
    ARROW="→"
else
    CHECKMARK="[+]"
    CROSSMARK="[-]"
    BULLET="*"
    ARROW=">"
fi

# Get the directory where the script is located (project root)
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Log and Backup directories in project root
LOG_BASE_DIR="${SCRIPT_ROOT}/Logs"
BACKUP_BASE_DIR="${SCRIPT_ROOT}/Backup"
MAIN_LOG_FILE="${LOG_BASE_DIR}/main.log"

# Section-specific logging
SECTION_NAME=""
SECTION_LOG_FILE=""
SECTION_BACKUP_DIR=""

# Initialize base directories (called once at startup)
init_directories() {
    if [ ! -d "$LOG_BASE_DIR" ]; then
        mkdir -p "$LOG_BASE_DIR"
    fi
    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        mkdir -p "$BACKUP_BASE_DIR"
    fi
    
    # Initialize main log if it doesn't exist
    if [ ! -f "$MAIN_LOG_FILE" ]; then
        {
            echo "=========================================="
            echo "ROCKY SECURE UTILITY - System started"
            echo "$(date)"
            echo "==========================================="
            echo ""
        } > "$MAIN_LOG_FILE"
    fi
}

log_success() {
    echo "[${FG_GREEN}${CHECKMARK}${RESET}] $(date '+%F %T') ${FG_GREEN}SUCCESS:${RESET} $1" | tee -a "$MAIN_LOG_FILE"
    if [ -n "$SECTION_LOG_FILE" ] && [ ! "$SECTION_LOG_FILE" = "$MAIN_LOG_FILE" ]; then
        echo "[${FG_GREEN}${CHECKMARK}${RESET}] $(date '+%F %T') ${FG_GREEN}SUCCESS:${RESET} $1" >> "$SECTION_LOG_FILE"
    fi
}

log_warning() {
    echo "[${FG_YELLOW}!${RESET}] $(date '+%F %T') ${FG_YELLOW}WARNING:${RESET} $1" | tee -a "$MAIN_LOG_FILE"
    if [ -n "$SECTION_LOG_FILE" ] && [ ! "$SECTION_LOG_FILE" = "$MAIN_LOG_FILE" ]; then
        echo "[${FG_YELLOW}!${RESET}] $(date '+%F %T') ${FG_YELLOW}WARNING:${RESET} $1" >> "$SECTION_LOG_FILE"
    fi
}

log_error() {
    echo "[${FG_RED}${CROSSMARK}${RESET}] $(date '+%F %T') ${FG_RED}ERROR:${RESET} $1" | tee -a "$MAIN_LOG_FILE"
    if [ -n "$SECTION_LOG_FILE" ] && [ ! "$SECTION_LOG_FILE" = "$MAIN_LOG_FILE" ]; then
        echo "[${FG_RED}${CROSSMARK}${RESET}] $(date '+%F %T') ${FG_RED}ERROR:${RESET} $1" >> "$SECTION_LOG_FILE"
    fi
}

log_info() {
    echo "[${FG_CYAN}i${RESET}] $(date '+%F %T') ${FG_CYAN}INFO:${RESET} $1" | tee -a "$MAIN_LOG_FILE"
    if [ -n "$SECTION_LOG_FILE" ] && [ ! "$SECTION_LOG_FILE" = "$MAIN_LOG_FILE" ]; then
        echo "[${FG_CYAN}i${RESET}] $(date '+%F %T') ${FG_CYAN}INFO:${RESET} $1" >> "$SECTION_LOG_FILE"
    fi
}

draw_header() {
clear
echo "${FG_PURPLE}${BOLD}┌──────────────────────────────────────────────────────┐"
echo "${FG_BLUE}${BOLD}│                                                      │${RESET}     ${FG_BLUE}░░░░░▄▄▀▀▀▀▀▀▀▀▀▄▄░░░░░${RESET}"
echo "${FG_BLUE}${BOLD}│   ROCKY SECURE UTILITY  - System Hardening Tool      │${RESET}     ${FG_BLUE}░░░░█░░░░░░░░░░░░░█░░░░${RESET}"
echo "${FG_BLUE}${BOLD}│   Author: St1c1n        | OS: Rocky Linux 9.7        │${RESET}     ${FG_BLUE}░░░█░░░░░░░░░░▄▄▄░░█░░░${RESET}"
echo "${FG_BLUE}${BOLD}│   Purpose: System security audit and configuration   │${RESET}     ${FG_BLUE}░░░█░░▄▄▄░░▄░░███░░█░░░${RESET}"
echo "${FG_BLUE}${BOLD}│                                                      │${RESET}     ${FG_BLUE}░░░▄█░▄░░░▀▀▀░░░▄░█▄░░░${RESET}"
echo "${FG_PURPLE}${BOLD}└──────────────────────────────────────────────────────┘${RESET}   ${FG_BLUE}~~~~~~~~~~~~~~~~~~~~~~~${RESET}"
echo "${RESET}"
}
draw_header_two() {
echo "${FG_PURPLE}${BOLD}╔══════════════════════════════════════════════════════╗"
echo "${FG_BLUE}${BOLD}║      *                               *        *      ║"
echo "${FG_BLUE}${BOLD}║             ROCKY SECURE UTILITY                 *   ║"
echo "${FG_BLUE}${BOLD}║   *     *                                 *          ║"
echo "${FG_BLUE}${BOLD}║             SYSTEM HARDENING CONSOLE           *     ║"
echo "${FG_BLUE}${BOLD}║         *                            *      *        ║"
echo "${FG_PURPLE}${BOLD}╚══════════════════════════════════════════════════════╝"
echo "${RESET}"
}

# Prompt for yes/no confirmation
# Usage: prompt_yes_no "Your question?" "yes" or "no"
# Returns: 0 for yes, 1 for no
prompt_yes_no() {
    local question="$1"
    local default="${2:-no}"
    local answer
    
    if [[ "$default" == "yes" ]]; then
        read -rp "${FG_CYAN}${BOLD}${question} (Y/n): ${RESET}" answer
        answer=${answer:-y}
    else
        read -rp "${FG_CYAN}${BOLD}${question} (y/N): ${RESET}" answer
        answer=${answer:-n}
    fi
    
    case "$answer" in
        [Yy]) return 0 ;;
        [Nn]) return 1 ;;
        *) 
            echo "${FG_RED}Invalid input. Please enter 'y' or 'n'.${RESET}"
            prompt_yes_no "$question" "$default"
            return $?
            ;;
    esac
}

# Prompt for input with default value
# Usage: prompt_with_default "Enter value" "default_value"
# Returns: user input or default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local input
    
    read -rp "${FG_CYAN}${BOLD}${prompt} [${default}]: ${RESET}" input
    echo "${input:-$default}"
}

cleanup_on_exit() {
echo
while true; do
read -rp "${FG_CYAN}${BOLD}Remove installed packages? (y/n): ${RESET}" ans
case "$ans" in
y|Y)
echo "${FG_YELLOW}Removing packages...${RESET}"
# Remove major packages installed by the tool
local packages_to_remove=("fail2ban" "lynis" "aide" "auditd" "policycoreutils-python-utils" "dnf-automatic")
for pkg in "${packages_to_remove[@]}"; do
    if dnf list installed "$pkg" &>/dev/null 2>&1; then
        dnf remove -y "$pkg" &>/dev/null
    fi
done
echo "${FG_GREEN}Packages removed.${RESET}"
break
;;
n|N)
echo "${FG_GREEN}Packages left in the system.${RESET}"
echo "${FG_RED}${BOLD}─▄████▄████▄"
echo "${FG_RED}${BOLD}██▒▒▒▒█▒▒▒▒██"
echo "${FG_RED}${BOLD}▀██▒▒▒▒▒▒▒██▀"
echo "${FG_RED}${BOLD}─▀██▒▒▒▒▒██▀"
echo "${FG_RED}${BOLD}───▀██▒██▀"
echo "${FG_RED}${BOLD}─────▀█▀"
echo "${RESET}"
break
;;
*)
echo "${FG_RED}Invalid input. Enter only y or n.${RESET}"
;;
esac
done
sleep 2
clear
}

view_logs() {
    clear
    draw_header
    echo "${FG_ORANGE}${BOLD}=== VIEW LOGS ===${RESET}"
    if [ -f "$MAIN_LOG_FILE" ]; then
        echo "${FG_CYAN}Main System Logs:${RESET}"
        echo "=================================================="
        tail -50 "$MAIN_LOG_FILE"
    else
        echo "${FG_YELLOW}No main log file found.${RESET}"
    fi
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

# Section-specific functions
init_section_logging() {
    local section_name="$1"
    SECTION_NAME="$section_name"
    
    # Create section directories
    SECTION_LOG_DIR="${LOG_BASE_DIR}/${section_name}"
    SECTION_LOG_FILE="${SECTION_LOG_DIR}/${section_name}.log"
    SECTION_BACKUP_DIR="${BACKUP_BASE_DIR}/${section_name}"
    
    mkdir -p "$SECTION_LOG_DIR"
    mkdir -p "$SECTION_BACKUP_DIR"
    
    # Add header to section log file if it's new
    if [ ! -f "$SECTION_LOG_FILE" ]; then
        {
            echo "=========================================="
            echo "Section: $SECTION_NAME"
            echo "Created: $(date)"
            echo "==========================================="
            echo ""
        } >> "$SECTION_LOG_FILE"
    else
        # Append session separator to existing log
        {
            echo ""
            echo "=========================================="
            echo "New session: $(date)"
            echo "=========================================="
            echo ""
        } >> "$SECTION_LOG_FILE"
    fi
    
    log_info "Initialized section: $SECTION_NAME"
}

log_section_success() {
    if [ -z "$SECTION_LOG_FILE" ]; then
        log_success "$1"
        return
    fi
    echo "[${FG_GREEN}${CHECKMARK}${RESET}] $(date '+%F %T') ${FG_GREEN}SUCCESS:${RESET} $1" | tee -a "$SECTION_LOG_FILE" "$MAIN_LOG_FILE"
}

log_section_warning() {
    if [ -z "$SECTION_LOG_FILE" ]; then
        log_warning "$1"
        return
    fi
    echo "[${FG_YELLOW}!${RESET}] $(date '+%F %T') ${FG_YELLOW}WARNING:${RESET} $1" | tee -a "$SECTION_LOG_FILE" "$MAIN_LOG_FILE"
}

log_section_error() {
    if [ -z "$SECTION_LOG_FILE" ]; then
        log_error "$1"
        return
    fi
    echo "[${FG_RED}${CROSSMARK}${RESET}] $(date '+%F %T') ${FG_RED}ERROR:${RESET} $1" | tee -a "$SECTION_LOG_FILE" "$MAIN_LOG_FILE"
}

log_section_info() {
    if [ -z "$SECTION_LOG_FILE" ]; then
        log_info "$1"
        return
    fi
    echo "[${FG_CYAN}i${RESET}] $(date '+%F %T') ${FG_CYAN}INFO:${RESET} $1" | tee -a "$SECTION_LOG_FILE" "$MAIN_LOG_FILE"
}

create_section_backup() {
    clear
    draw_header
    echo "${FG_GREEN}${BOLD}=== CREATE SECTION BACKUP ===${RESET}"
    
    if [ -z "$SECTION_NAME" ]; then
        echo "${FG_RED}Error: Section not initialized${RESET}"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return 1
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${SECTION_BACKUP_DIR}/backup_${SECTION_NAME}_${timestamp}"
    
    echo "Creating backup for section: $SECTION_NAME"
    echo "Backup location: $backup_file"
    
    # Create backup of section-specific files
    mkdir -p "$SECTION_BACKUP_DIR"
    
    # Backup section log file if it exists
    if [ -f "$SECTION_LOG_FILE" ]; then
        cp "$SECTION_LOG_FILE" "$backup_file" 2>/dev/null
        log_section_info "Section backup created: $backup_file"
        echo "${FG_GREEN}${CHECKMARK} Backup created successfully${RESET}"
    else
        echo "${FG_YELLOW}No section files to backup${RESET}"
    fi
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

view_section_logs() {
    clear
    draw_header
    echo "${FG_ORANGE}${BOLD}=== VIEW SECTION LOGS ===${RESET}"
    
    if [ -z "$SECTION_NAME" ]; then
        echo "${FG_RED}Error: Section not initialized${RESET}"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return 1
    fi
    
    if [ -f "$SECTION_LOG_FILE" ]; then
        echo "${FG_CYAN}Logs for section: $SECTION_NAME${RESET}"
        echo "=================================================="
        cat "$SECTION_LOG_FILE"
    else
        echo "${FG_YELLOW}No logs found for section: $SECTION_NAME${RESET}"
    fi
    echo "=================================================="
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

restore_section_backup() {
    clear
    draw_header
    echo "${FG_PURPLE}${BOLD}=== RESTORE FROM SECTION BACKUP ===${RESET}"
    
    if [ -z "$SECTION_NAME" ]; then
        echo "${FG_RED}Error: Section not initialized${RESET}"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return 1
    fi
    
    if [ ! -d "$SECTION_BACKUP_DIR" ] || [ -z "$(ls -A "$SECTION_BACKUP_DIR" 2>/dev/null)" ]; then
        echo "${FG_YELLOW}No backups found for section: $SECTION_NAME${RESET}"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return 1
    fi
    
    echo "${FG_CYAN}Available backups for $SECTION_NAME:${RESET}"
    ls -lh "$SECTION_BACKUP_DIR"/backup_* 2>/dev/null | nl
    
    read -rp "${FG_CYAN}Select backup number to restore (or 0 to cancel): ${RESET}" choice
    
    if [ "$choice" = "0" ]; then
        return 0
    fi
    
    local backup_file=$(ls -1 "$SECTION_BACKUP_DIR"/backup_* 2>/dev/null | sed -n "${choice}p")
    
    if [ -z "$backup_file" ]; then
        echo "${FG_RED}Invalid selection${RESET}"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return 1
    fi
    
    echo "${FG_GREEN}${CHECKMARK} Restore completed${RESET}"
    cp "$backup_file" "$SECTION_LOG_FILE" 2>/dev/null
    log_section_info "Section restored from backup: $backup_file"
    echo "${FG_GREEN}✓ Restore completed${RESET}"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}