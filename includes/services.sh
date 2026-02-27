# includes/services.sh
#!/bin/bash

# Services management section: Handles disabling unnecessary services for Rocky Linux 9.7

configure_disable_services() {
    clear
    draw_header
    echo "${FG_MAGENTA}${BOLD}=== DISABLE UNNECESSARY SERVICES ===${RESET}"
    echo ""
    
    log_section_info "Disabling unnecessary services..."
    
    echo "Disabling unnecessary services to minimize attack surface..."
    echo ""
    
    # List of services to disable (can be modified based on requirements)
    local services_to_disable=(
        "avahi-daemon"      # mDNS/DNS-SD
        "cups"              # Printing
        "cups-lpd"          # Line Printer Daemon
        "isc-dhcp-server"   # DHCP Server
        "isc-dhcp-server6"  # DHCPv6 Server
        "vsftpd"            # FTP
        "tftp"              # TFTP
        "snmpd"             # SNMP
        "nis"               # NIS
        "rsync"             # Rsync
        "ypbind"            # NIS client
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            echo -ne "Disabling $service... "
            systemctl disable "$service" &>/dev/null
            systemctl stop "$service" &>/dev/null
            if ! systemctl is-active --quiet "$service"; then
                echo "${FG_GREEN}${CHECKMARK}${RESET}"
                log_section_success "Disabled service: $service"
            else
                echo "${FG_YELLOW}${CROSSMARK}${RESET}"
                log_section_warning "Failed to disable: $service"
            fi
        fi
    done
    
    echo ""
    echo "Disabling unnecessary modules..."
    
    # Disable USB storage
    echo "install usb-storage /bin/true" > /etc/modprobe.d/disable-usb-storage.conf
    echo "${FG_GREEN}${CHECKMARK} USB storage disabled${RESET}"
    log_section_info "USB storage module disabled"
    
    # Disable uncommon filesystems
    cat > /etc/modprobe.d/disable-filesystems.conf << 'EOF'
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
EOF
    
    echo "${FG_GREEN}${CHECKMARK} Uncommon filesystems disabled${RESET}"
    log_section_success "Unnecessary filesystems disabled"
    
    # Disable uncommon network protocols
    cat > /etc/modprobe.d/disable-protocols.conf << 'EOF'
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
EOF
    
    echo "${FG_GREEN}${CHECKMARK} Unnecessary protocols disabled${RESET}"
    log_section_success "Unnecessary network protocols disabled"
    
    # Disable Firewire storage (IEEE1394)
    echo "install firewire-core /bin/true" > /etc/modprobe.d/disable-firewire.conf
    echo "install firewire-sbp2 /bin/true" >> /etc/modprobe.d/disable-firewire.conf
    echo "${FG_GREEN}${CHECKMARK} Firewire storage disabled${RESET}"
    log_section_success "Firewire storage disabled"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

submenu_services() {
init_section_logging "services"
while true; do
clear
draw_header
echo "${FG_MAGENTA}${BOLD}=== SERVICES MANAGEMENT ===${RESET}"
echo ""
echo "${FG_MAGENTA}${BOLD}╔══════════════════════════════════════════════════════╗"
echo "${FG_MAGENTA}${BOLD}║   This section allows disabling unnecessary services ║"
echo "${FG_MAGENTA}${BOLD}║   and features to minimize the attack surface.       ║"
echo "${FG_MAGENTA}${BOLD}║   Disabling unused network services,                 ║"
echo "${FG_MAGENTA}${BOLD}║   hardware interfaces and file systems.              ║"
echo "${FG_MAGENTA}${BOLD}║   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ║"
echo "${FG_MAGENTA}${BOLD}╚══════════════════════════════════════════════════════╝"
echo "${RESET}"
echo "1) Disable unnecessary services"
echo "2) Create section backup"
echo "3) View logs"
echo "4) Restore from backup"
echo ""
echo "0) Back"
echo ""
read -rp "Select: " choice
case $choice in
1) configure_disable_services ;;
2) create_section_backup ;;
3) view_section_logs ;;
4) restore_section_backup ;;
0) break ;;
*) ;;
esac
done
}
