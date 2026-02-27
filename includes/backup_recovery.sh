# includes/backup_recovery.sh
#!/bin/bash

# Backup and recovery section: Handles backups and restores for Rocky Linux 9.7

backup_current_config() {
    clear
    draw_header
    echo "${FG_PURPLE}${BOLD}=== CREATE FULL SYSTEM BACKUP ===${RESET}"
    echo ""
    
    log_section_info "Creating full system configuration backup..."
    
    local backup_base_dir="${BACKUP_BASE_DIR}/backup_recovery"
    local backup_folder="${backup_base_dir}/backup_system_full"
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_archive="${backup_base_dir}/Full_backup_system_${backup_timestamp}"
    
    # Create backup base directory
    mkdir -p "$backup_base_dir"
    
    # Create or use existing backup folder
    if [ ! -d "$backup_folder" ]; then
        mkdir -p "$backup_folder"
        echo "${FG_GREEN}${CHECKMARK} Created backup directory: $backup_folder${RESET}"
        log_section_info "Created backup directory: $backup_folder"
    else
        echo "${FG_GREEN}${CHECKMARK} Using existing backup directory: $backup_folder${RESET}"
        log_section_info "Using existing backup directory: $backup_folder"
    fi
    
    echo ""
    echo "Scanning configuration directories..."
    echo "======================================"
    echo ""
    
    # List of important configuration directories
    local backup_paths=(
        "/etc/ssh/"
        "/etc/sysctl.d/"
        "/etc/security/"
        "/etc/pam.d/"
        "/etc/audit/"
        "/etc/selinux/"
        "/etc/sudoers.d/"
        "/etc/modprobe.d/"
        "/etc/firewalld/"
    )
    
    # Check and copy directories
    local backup_count=0
    for path in "${backup_paths[@]}"; do
        if [ -e "$path" ]; then
            echo -ne "Backing up ${path}... "
            cp -r "$path" "$backup_folder/" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "${FG_GREEN}${CHECKMARK}${RESET}"
                log_section_success "Backed up: $path"
                backup_count=$((backup_count + 1))
            else
                echo "${FG_YELLOW}⊘${RESET} (skipped - permission issue)"
                log_section_warning "Skipped backup of: $path"
            fi
        else
            echo "${FG_YELLOW}⊘${RESET} Not found: $path"
        fi
    done
    
    echo ""
    echo "======================================"
    echo "${FG_GREEN}${BOLD}Backup completed!${RESET}"
    echo "Backup location: $backup_folder"
    echo "${FG_GREEN}${BOLD}Total directories backed up: $backup_count${RESET}"
    echo ""
    
    # Show backup folder contents
    echo "Backup folder contents:"
    echo "======================"
    du -sh "$backup_folder" 2>/dev/null
    echo ""
    ls -lh "$backup_folder" 2>/dev/null | tail -10
    
    log_section_success "Full system backup created: $backup_folder"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

restore_from_backup() {
    clear
    draw_header
    echo "${FG_PURPLE}${BOLD}=== RESTORE FROM BACKUP ===${RESET}"
    echo ""
    
    log_section_info "Restoring from backup..."
    
    local backup_dir="${BACKUP_BASE_DIR}/backup_recovery"
    
    if [ ! -d "$backup_dir" ] || [ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]; then
        echo "${FG_YELLOW}No backups found${RESET}"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return 1
    fi
    
    echo "Available backups:"
    echo "=================="
    ls -lh "$backup_dir"/ | nl
    
    read -rp "${FG_CYAN}Select backup number to restore: ${RESET}" choice
    
    local backup_file=$(ls -1 "$backup_dir"/ | sed -n "${choice}p")
    
    if [ -z "$backup_file" ]; then
        echo "${FG_RED}Invalid selection${RESET}"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return 1
    fi
    
    echo "${FG_YELLOW}WARNING: This will restore system configuration${RESET}"
    read -rp "${FG_YELLOW}Continue? (y/N): ${RESET}" confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        tar -xzf "${backup_dir}/${backup_file}" -C / 2>/dev/null
        log_section_success "System restored from backup: $backup_file"
        echo "${FG_GREEN}${CHECKMARK} Restore completed${RESET}"
    fi
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

export_settings() {
    clear
    draw_header
    echo "${FG_PURPLE}${BOLD}=== EXPORT SETTINGS ===${RESET}"
    echo ""
    
    log_section_info "Exporting security settings..."
    
    local export_dir="${BACKUP_BASE_DIR}/exports"
    local export_file="${export_dir}/settings_export_$(date +%Y%m%d_%H%M%S).txt"
    
    mkdir -p "$export_dir"
    
    echo "Exporting system security configuration..."
    echo "Export file: $export_file"
    echo ""
    
    {
        echo "===== ROCKY LINUX 9.7 SECURITY SETTINGS EXPORT ====="
        echo "Generated: $(date)"
        echo ""
        echo "=== SSH Configuration ==="
        grep -v "^#" /etc/ssh/sshd_config | grep -v "^$"
        echo ""
        echo "=== Firewall Rules ==="
        firewall-cmd --list-all 2>/dev/null || echo "Firewall not configured"
        echo ""
        echo "=== Audit Rules ==="
        auditctl -l 2>/dev/null || echo "Audit not configured"
        echo ""
        echo "=== SELinux Status ==="
        getenforce 2>/dev/null || echo "SELinux not available"
        echo ""
        echo "=== Active Services ==="
        systemctl list-units --type=service --state=running | grep -v "loaded"
        echo ""
        echo "=== Kernel Parameters ==="
        sysctl -a 2>/dev/null | grep -E "(net\.|kernel\.)" | head -30
    } > "$export_file"
    
    log_section_success "Settings exported: $export_file"
    echo "${FG_GREEN}${CHECKMARK} Export completed${RESET}"
    echo "File size: $(du -h "$export_file" | cut -f1)"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

import_settings() {
    clear
    draw_header
    echo "${FG_PURPLE}${BOLD}=== IMPORT SETTINGS ===${RESET}"
    echo ""
    
    log_section_info "Importing security settings..."
    
    echo "This function would allow importing settings from a previously exported configuration."
    echo ""
    echo "${FG_YELLOW}Note: Manual import is recommended for safety.${RESET}"
    echo "Please copy the exported settings file to the system and apply manually."
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

submenu_backup_recovery() {
init_section_logging "backup_recovery"
while true; do
clear
draw_header
echo "${FG_PURPLE}${BOLD}=== BACKUP AND RECOVERY ===${RESET}"
echo ""
echo "${FG_PURPLE}${BOLD}╔══════════════════════════════════════════════════════╗"
echo "${FG_PURPLE}${BOLD}║   This section allows creating configuration backups ║"
echo "${FG_PURPLE}${BOLD}║   and restoring the system from backup.              ║"
echo "${FG_PURPLE}${BOLD}║   Export/import settings for transfer between systems║"
echo "${FG_PURPLE}${BOLD}║   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ║"
echo "${FG_PURPLE}${BOLD}╚══════════════════════════════════════════════════════╝"
echo "${RESET}"
echo "1) Create backup"
echo "2) Restore from backup"
echo "3) Export settings"
echo "4) Import settings"
echo "5) Create section backup"
echo "6) View logs"
echo "7) Restore section backup"
echo ""
echo "0) Back"
echo ""
read -rp "Select: " choice
case $choice in
1) backup_current_config ;;
2) restore_from_backup ;;
3) export_settings ;;
4) import_settings ;;
5) create_section_backup ;;
6) view_section_logs ;;
7) restore_section_backup ;;
0) break ;;
*) ;;
esac
done
}