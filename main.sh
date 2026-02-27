# main.sh
#!/bin/bash

# Main script for Rocky Linux 9 security hardening
# Usage: sudo ./main.sh

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use: sudo ./main.sh)"
    exit 1
fi

# Load all modules
source includes/helpers.sh
source includes/preparation.sh
source includes/critical.sh
source includes/system_hardening.sh
source includes/access_control.sh
source includes/services.sh
source includes/audit_logs.sh
source includes/backup_recovery.sh
source includes/additional_tools.sh
source includes/doker.sh

# Initialize directory structure and main logging
init_directories
log_info "Rocky Security Utility started - Rocky Linux 9.7"

tabs=("PREPARATION" "CRITICAL" "SYSTEM" "ACCESS" "SERVICES" "AUDIT" "BACKUP" "ADDITIONAL" "DOCKER")
num_tabs=${#tabs[@]}
current=0

while true; do
draw_header
draw_header_two
echo ""
echo -n "${FG_PURPLE}${BOLD}"
for i in "${!tabs[@]}"; do
if [[ $i -eq $current ]]; then
echo -n "${FG_BLUE}${REVERSE}[ ${tabs[$i]} ]${RESET}${FG_PURPLE}${BOLD}"
else
echo -n "[ ${tabs[$i]} ] "
fi
done
echo "${RESET}"
echo ""
echo "${FG_BLUE}${BOLD}========================================================"
echo "${FG_PURPLE}${BOLD}< > / Tab — navigation | Enter — select           "
echo "${FG_BLUE}========================================================"
echo ""
echo "${FG_RED}${BOLD}[ ESC ] EXIT${RESET}"
read -rsn1 key
if [[ $key == $'\x1b' ]]; then
    # ESC sequence - read the rest
    read -rsn2 -t 0.1 key_seq
    key+="$key_seq"
    case "$key" in
        *'[C') current=$(( (current + 1) % num_tabs )) ;;
        *'[D') current=$(( (current - 1 + num_tabs) % num_tabs )) ;;
        $'\x1b') clear; cleanup_on_exit; exit 0 ;;
    esac
else
    case "$key" in
        $'\t') current=$(( (current + 1) % num_tabs )) ;;
        $'\n'|'') 
            case $current in
                0) submenu_preparation ;;
                1) submenu_critical ;;
                2) submenu_system_hardening ;;
                3) submenu_access_control ;;
                4) submenu_services ;;
                5) submenu_audit_logs ;;
                6) submenu_backup_recovery ;;
                7) submenu_additional_tools ;;
                8) submenu_docker ;;
            esac
        ;;
    esac
fi
done