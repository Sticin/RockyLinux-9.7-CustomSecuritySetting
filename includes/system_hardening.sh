# includes/system_hardening.sh
#!/bin/bash

# System hardening section: Handles kernel and filesystem security enhancements for Rocky Linux 9.7

configure_sysctl() {
    clear
    draw_header
    echo "${FG_BLUE}${BOLD}=== KERNEL PARAMETERS ===${RESET}"
    echo ""
    
    log_section_info "Configuring kernel parameters (sysctl)..."
    
    local sysctl_config="/etc/sysctl.d/99-hardening.conf"
    local sysctl_backup="${SECTION_BACKUP_DIR}/sysctl_backup_$(date +%Y%m%d_%H%M%S)"
    
    # Backup current sysctl settings
    sysctl -a > "$sysctl_backup"
    log_section_info "Sysctl settings backed up: $sysctl_backup"
    echo "${FG_GREEN}${CHECKMARK} Backed up current settings${RESET}"
    
    echo ""
    echo "${FG_CYAN}Kernel Parameter Configuration:${RESET}"
    echo "=========================================="
    echo ""
    
    # Interactive configuration
    if prompt_yes_no "Enable ASLR (Address Space Layout Randomization)?" "yes"; then
        local aslr="2"
        echo "${FG_GREEN}${CHECKMARK} ASLR enabled${RESET}"
    else
        local aslr="0"
        echo "${FG_GREEN}${CHECKMARK} ASLR disabled${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Enable IP forwarding?" "no"; then
        local ip_forward="1"
        echo "${FG_GREEN}${CHECKMARK} IP forwarding enabled${RESET}"
    else
        local ip_forward="0"
        echo "${FG_GREEN}${CHECKMARK} IP forwarding disabled${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Use IPv6?" "no"; then
        local enable_ipv6="1"
        echo "${FG_GREEN}${CHECKMARK} IPv6 enabled${RESET}"
    else
        local enable_ipv6="0"
        echo "${FG_GREEN}${CHECKMARK} IPv6 disabled${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Enable kernel module loading restrictions?" "yes"; then
        local modules_disabled="1"
        echo "${FG_GREEN}${CHECKMARK} Kernel module loading restricted${RESET}"
    else
        local modules_disabled="0"
        echo "${FG_GREEN}${CHECKMARK} Kernel module loading enabled${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Disable Magic SysRq key?" "yes"; then
        local sysrq="0"
        echo "${FG_GREEN}${CHECKMARK} Magic SysRq disabled${RESET}"
    else
        local sysrq="1"
        echo "${FG_GREEN}${CHECKMARK} Magic SysRq enabled${RESET}"
    fi
    
    echo ""
    echo "Applying kernel security hardening..."
    echo ""
    
    # Calculate IPv6 disable value
    local disable_ipv6=$([[ "$enable_ipv6" == "1" ]] && echo "0" || echo "1")
    
    # Create hardening configuration
    cat > "$sysctl_config" << EOF
# Kernel security hardening for Rocky Linux 9.7

# Kernel protection
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.printk = 3 3 3 3
kernel.unprivileged_ns_clone = 0
kernel.unprivileged_userns_clone = 0

# Core dump restriction
kernel.core_uses_pid = 1
fs.suid_dumpable = 0

# ASLR
kernel.randomize_va_space = $aslr

# Restrict kernel module loading
kernel.modules_disabled = $modules_disabled

# Magic SysRq is disabled
kernel.sysrq = $sysrq

# Hide kernel pointer exposure
kernel.perf_event_paranoid = 3

# Restrict access to kernel logs
kernel.kexec_load_disabled = 1

# Restrict ptrace scope
kernel.yama.ptrace_scope = 2

# TCP hardening
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.ip_forward = $ip_forward

# IPv6 hardening
net.ipv6.conf.all.disable_ipv6 = $disable_ipv6
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
# File system
fs.file-max = 65535
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_regular = 1
fs.protected_fifos = 2

# Core dumps
kernel.core_uses_pid = 1
EOF
    
# Apply sysctl settings
sysctl -p "$sysctl_config" &>/dev/null
log_section_success "Kernel parameters configured"
echo "${FG_GREEN}${CHECKMARK} Kernel parameters applied${RESET}"

echo ""
echo "New kernel parameters:"
echo "====================="
sysctl -p "$sysctl_config" 2>/dev/null

read -rp "${FG_GREEN}Press Enter to return...${RESET}"

configure_filesystem() {
    clear
    draw_header
    echo "${FG_BLUE}${BOLD}=== FILESYSTEM SECURITY ===${RESET}"
    echo ""
    
    log_section_info "Configuring filesystem security..."
    
    echo "${FG_CYAN}Filesystem Security Configuration:${RESET}"
    echo "=========================================="
    echo ""
    
    # Check and modify mount options in fstab
    local fstab_backup="${SECTION_BACKUP_DIR}/fstab_backup_$(date +%Y%m%d_%H%M%S)"
    cp /etc/fstab "$fstab_backup"
    log_section_info "fstab backed up: $fstab_backup"
    echo "${FG_GREEN}${CHECKMARK} Backed up fstab${RESET}"
    
    echo ""
    if prompt_yes_no "Apply security options to /home partition?" "yes"; then
        if grep -q "^/.*home" /etc/fstab; then
            echo "${FG_GREEN}${CHECKMARK} Home partition found${RESET}"
            sed -i 's|^\(/.*home.*\)defaults\(.*\)$|\1defaults,nodev,nosuid,noexec\2|g' /etc/fstab
            log_section_success "Home partition security options set"
            echo "${FG_GREEN}${CHECKMARK} Applied: nodev,nosuid,noexec${RESET}"
        else
            echo "${FG_YELLOW}⚠ Home partition not found in fstab${RESET}"
        fi
    fi
    
    echo ""
    if prompt_yes_no "Apply security options to /tmp partition?" "yes"; then
        if grep -q "^.*[[:space:]]/tmp[[:space:]]" /etc/fstab; then
            sed -i 's|^\(.*[[:space:]]/tmp[[:space:]].*\)defaults\(.*\)$|\1defaults,nodev,nosuid,noexec\2|g' /etc/fstab
            log_section_success "/tmp partition security options set"
            echo "${FG_GREEN}${CHECKMARK} Applied: nodev,nosuid,noexec${RESET}"
        else
            echo "${FG_YELLOW}⚠ /tmp partition not found in fstab${RESET}"
        fi
    fi
    
    echo ""
    if prompt_yes_no "Disable uncommon filesystems?" "yes"; then
        cat >> /etc/modprobe.d/disable-filesystems.conf << 'EOF'
# Disable uncommon filesystems
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
install vfat /bin/true
EOF
        log_section_success "Uncommon filesystems disabled"
        echo "${FG_GREEN}${CHECKMARK} Uncommon filesystems disabled${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Disable uncommon network protocols?" "yes"; then
        cat >> /etc/modprobe.d/disable-protocols.conf << 'EOF'
# Disable uncommon network protocols
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
EOF
        log_section_success "Uncommon network protocols disabled"
        echo "${FG_GREEN}${CHECKMARK} Uncommon protocols disabled${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Disable USB storage?" "yes"; then
        cat > /etc/modprobe.d/disable-usb-storage.conf << 'EOF'
# Disable USB storage
install usb-storage /bin/true
EOF
        log_section_success "USB storage disabled"
        echo "${FG_GREEN}${CHECKMARK} USB storage disabled${RESET}"
    fi
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

configure_selinux() {
    clear
    draw_header
    echo "${FG_BLUE}${BOLD}=== SELINUX CONFIGURATION ===${RESET}"
    echo ""
    
    log_section_info "Configuring SELinux..."
    
    echo "${FG_CYAN}SELinux Configuration:${RESET}"
    echo "=========================================="
    echo ""
    
    local selinux_config="/etc/selinux/config"
    local selinux_backup="${SECTION_BACKUP_DIR}/selinux_backup_$(date +%Y%m%d_%H%M%S)"
    
    # Backup SELinux config
    if [ -f "$selinux_config" ]; then
        cp "$selinux_config" "$selinux_backup"
        log_section_info "SELinux config backed up: $selinux_backup"
        echo "${FG_GREEN}${CHECKMARK} Backed up SELinux config${RESET}"
    fi
    
    # Install SELinux tools if not present
    if ! dnf list installed policycoreutils-python-utils 2>/dev/null | grep -q "Installed"; then
        echo "Installing SELinux tools..."
        dnf install -y policycoreutils-python-utils &>/dev/null
    fi
    
    # Check current SELinux status
    if command -v getenforce &>/dev/null; then
        local current_selinux=$(getenforce)
        echo "Current SELinux status: $current_selinux"
        echo ""
        
        # Interactive SELinux mode selection
        echo "Select SELinux mode:"
        echo "  1) Enforcing (strict security, recommended)"
        echo "  2) Permissive (log violations, no enforcement)"
        echo "  3) Disabled (no SELinux protection)"
        read -rp "Select mode (1-3, default 1): " selinux_mode
        selinux_mode=${selinux_mode:-1}
        
        case $selinux_mode in
            1) 
                local selinux_value="enforcing"
                echo "${FG_GREEN}${CHECKMARK} Enforcing mode selected${RESET}"
                log_section_info "SELinux mode set to enforcing"
                ;;
            2) 
                local selinux_value="permissive"
                echo "${FG_YELLOW}${CHECKMARK} Permissive mode selected${RESET}"
                log_section_warning "SELinux mode set to permissive (not recommended for production)"
                ;;
            3) 
                local selinux_value="disabled"
                echo "${FG_RED}${CHECKMARK} Disabled mode selected${RESET}"
                log_section_warning "SELinux disabled (not recommended)"
                ;;
            *)
                local selinux_value="enforcing"
                echo "${FG_GREEN}${CHECKMARK} Enforcing mode selected (default)${RESET}"
                ;;
        esac
        
        # Backup before modifying
        cp "$selinux_config" "${selinux_config}.bak_$(date +%Y%m%d_%H%M%S)"
        
        # Check if config file is writable
        if [ ! -w "$selinux_config" ]; then
            log_section_error "SELinux config file is not writable"
            echo "${FG_RED}${CROSSMARK} Cannot modify SELinux config (permission denied)${RESET}"
            return 1
        fi
        
        # Set SELinux mode
        sed -i "s/^SELINUX=.*/SELINUX=$selinux_value/" "$selinux_config"
        sed -i 's/^SELINUXTYPE=.*/SELINUXTYPE=targeted/' "$selinux_config"
        
        log_section_success "SELinux configured to $selinux_value mode"
        echo "${FG_GREEN}${CHECKMARK} SELinux configuration updated${RESET}"
        
        # Apply immediately if possible (only for enforcing and permissive)
        if [ "$selinux_value" = "enforcing" ]; then
            setenforce 1 2>/dev/null
            log_section_info "SELinux enforcing mode activated"
            echo "${FG_GREEN}${CHECKMARK} Enforcing mode activated immediately${RESET}"
        elif [ "$selinux_value" = "permissive" ]; then
            setenforce 0 2>/dev/null
            log_section_info "SELinux permissive mode activated"
            echo "${FG_GREEN}${CHECKMARK} Permissive mode activated immediately${RESET}"
        elif [ "$selinux_value" = "disabled" ]; then
            echo ""
            echo "${FG_YELLOW}${BOLD}⚠ REBOOT REQUIRED${RESET}"
            echo "${FG_YELLOW}SELinux disabled mode requires system reboot to take effect!${RESET}"
            log_section_warning "SELinux disabled mode requires reboot"
        fi
    else
        log_section_warning "SELinux tools not available"
        echo "${FG_YELLOW}${CROSSMARK} SELinux tools not found${RESET}"
    fi
    
    # Show SELinux status
    echo ""
    echo "SELinux Status:"
    echo "==============="
    if command -v getenforce &>/dev/null; then
        echo "Current mode: $(getenforce)"
        echo "Config mode: $(grep '^SELINUX=' $selinux_config | cut -d= -f2)"
    fi
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

configure_limits() {
    clear
    draw_header
    echo "${FG_BLUE}${BOLD}=== RESOURCE LIMITS & CORE DUMPS ===${RESET}"
    echo ""
    
    log_section_info "Configuring resource limits..."
    
    echo "Setting up security limits and disabled core dumps..."
    echo ""
    
    # Backup limits.conf
    cp /etc/security/limits.conf "${SECTION_BACKUP_DIR}/limits_conf_$(date +%Y%m%d_%H%M%S)"
    
    # Disable core dumps for all users
    cat >> /etc/security/limits.conf << 'EOF'

# Security: Disable core dumps
* soft core 0
* hard core 0
EOF
    
    log_section_success "Core dumps disabled in limits.conf"
    echo "${FG_GREEN}${CHECKMARK} Core dumps disabled for all users${RESET}"
fs.suid_dumpable = 0
EOF
    
    sysctl -p /etc/sysctl.d/99-hardening.conf &>/dev/null
    log_section_success "Core dump protection applied via sysctl"
    echo "${FG_GREEN}${CHECKMARK} Core dump restrictions applied${RESET}"
    
    # Restrict ptrace
    cat >> /etc/sysctl.d/99-hardening.conf << 'EOF'

# Restrict ptrace to prevent debugging attacks
kernel.yama.ptrace_scope = 2
EOF
    
    sysctl -p /etc/sysctl.d/99-hardening.conf &>/dev/null
    echo "${FG_GREEN}${CHECKMARK} Ptrace scope restricted${RESET}"
    log_section_success "Ptrace protection configured"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

configure_accounting() {
    clear
    draw_header
    echo "${FG_BLUE}${BOLD}=== PROCESS ACCOUNTING ===${RESET}"
    echo ""
    
    log_section_info "Enabling process accounting..."
    
    echo "Setting up process accounting for audit trail..."
    echo ""
    
    # Install psacct (process accounting)
    if ! dnf list installed psacct-ng 2>/dev/null | grep -q "Installed"; then
        echo "Installing psacct-ng (process accounting)..."
        dnf install -y psacct-ng sysstat &>/dev/null
        log_section_info "psacct-ng and sysstat installed"
        echo "${FG_GREEN}${CHECKMARK} Process accounting tools installed${RESET}"
    fi
    
    # Enable process accounting service
    systemctl enable psacct &>/dev/null
    systemctl start psacct &>/dev/null
    log_section_success "psacct service enabled"
    echo "${FG_GREEN}${CHECKMARK} Process accounting enabled${RESET}"
    
    # Enable system accounting tools (sar)
    if [ -f /etc/default/sysstat ]; then
        sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
    fi
    
    # Enable sysstat cron job
    systemctl enable sysstat &>/dev/null
    systemctl start sysstat &>/dev/null
    log_section_success "sysstat accounting enabled"
    echo "${FG_GREEN}${CHECKMARK} System statistics accounting enabled${RESET}"
    
    # Start data collection
    echo "Starting accounting data collection..."
    if command -v accton &>/dev/null; then
        touch /var/account/pacct
        accton /var/account/pacct
        echo "${FG_GREEN}${CHECKMARK} Process accounting active${RESET}"
        log_section_success "Process accounting active"
    fi
    
    echo ""
    echo "Accounting Features:"
    echo "  • Process accounting: /var/account/pacct"
    echo "  • System statistics: /var/log/sa/"
    echo "  • View process history: lastcomm"
    echo "  • View SA data: sar"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

submenu_system_hardening() {
init_section_logging "system_hardening"
while true; do
clear
draw_header
echo "${FG_BLUE}${BOLD}=== SYSTEM HARDENING ===${RESET}"
echo ""
echo "${FG_BLUE}${BOLD}╔══════════════════════════════════════════════════════╗"
echo "${FG_BLUE}${BOLD}║   This section contains kernel and filesystem        ║"
echo "${FG_BLUE}${BOLD}║   settings to enhance security at the OS level.      ║"
echo "${FG_BLUE}${BOLD}║   Kernel parameters, filesystem protection,          ║"
echo "${FG_BLUE}${BOLD}║   SELinux configuration for mandatory access control.║"
echo "${FG_BLUE}${BOLD}║   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ║"
echo "${FG_BLUE}${BOLD}╚══════════════════════════════════════════════════════╝"
echo "${RESET}"
echo "1) Kernel parameters"
echo "2) Filesystem security"
echo "3) SELinux configuration"
echo "4) Resource limits & core dumps"
echo "5) Process accounting"
echo "6) Create section backup"
echo "7) View logs"
echo "8) Restore from backup"
echo ""
echo "0) Back"
echo ""
read -rp "Select: " choice
case $choice in
1) configure_sysctl ;;
2) configure_filesystem ;;
3) configure_selinux ;;
4) configure_limits ;;
5) configure_accounting ;;
6) create_section_backup ;;
7) view_section_logs ;;
8) restore_section_backup ;;
0) break ;;
*) ;;
esac
done
}
