# includes/audit_logs.sh
#!/bin/bash

# Audit and logs section: Handles auditing and logging configurations for Rocky Linux 9.7

configure_auditd() {
    clear
    draw_header
    echo "${FG_ORANGE}${BOLD}=== AUDITD CONFIGURATION ===${RESET}"
    echo ""
    
    log_section_info "Configuring auditd..."
    
    echo "Setting up comprehensive audit logging..."
    echo ""
    
    # Install audit tools if not present
    if ! dnf list installed audit 2>/dev/null | grep -q "Installed"; then
        echo "Installing audit tools..."
        dnf install -y audit audit-libs &>/dev/null
    fi
    
    # Backup existing audit rules
    cp /etc/audit/rules.d/audit.rules "${SECTION_BACKUP_DIR}/audit.rules_$(date +%Y%m%d_%H%M%S)" 2>/dev/null
    
    # Create comprehensive audit rules
    cat > /etc/audit/rules.d/hardening.rules << 'EOF'
# Remove any existing rules
-D

# Buffer Size
-b 8192

# Failure Mode
-f 1

# File integrity monitoring
-w /usr/bin -p wa -k binaries
-w /usr/sbin -p wa -k binaries
-w /usr/local/bin -p wa -k binaries
-w /usr/local/sbin -p wa -k binaries

# System administration
-w /etc/group -p wa -k system-locale
-w /etc/passwd -p wa -k system-locale
-w /etc/gshadow -p wa -k system-locale
-w /etc/shadow -p wa -k system-locale
-w /etc/security/opasswd -p wa -k system-locale

# SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd_config

# Sudoers
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# Audit logs
-w /var/log/audit/ -k auditlog

# Kernel modules
-a always,exit -F arch=always -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=always -S clock_settime -k time-change
-a always,exit -F arch=always -S sethostname -S setdomainname -k network_modifications

# Make configuration immutable
-e 2
EOF
    
    # Load audit rules
    augenrules --load &>/dev/null
    auditctl -l &>/dev/null
    
    log_section_success "Auditd configuration applied"
    echo "${FG_GREEN}${CHECKMARK} Audit rules loaded${RESET}"
    
    # Enable and start auditd
    systemctl enable auditd &>/dev/null
    systemctl restart auditd &>/dev/null
    
    log_section_success "Auditd service enabled and started"
    echo "${FG_GREEN}${CHECKMARK} Auditd service running${RESET}"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

configure_logging() {
    clear
    draw_header
    echo "${FG_ORANGE}${BOLD}=== LOGGING AND MONITORING ===${RESET}"
    echo ""
    
    log_section_info "Configuring system logging and monitoring..."
    
    echo "Setting up comprehensive logging..."
    echo ""
    
    # Configure rsyslog
    cat > /etc/rsyslog.d/hardening.conf << 'EOF'
# Hardened rsyslog configuration

# Log authentication attempts
auth,authpriv.*                 /var/log/secure
auth,authpriv.info              /var/log/auth.log

# Log kernel messages
kern.*                          /var/log/kern.log

# Log system messages
*.info;kern.none                /var/log/messages

# Log cron messages
cron.*                          /var/log/cron

# Remote syslog (if needed)
# *.* @@remote.example.com:514

# Format logs with timestamps
$ActionFileDefaultTemplate RSYSLOG_FileFormat
$ActionFileTemplate RSYSLOG_FileFormat
EOF
    
    systemctl restart rsyslog &>/dev/null
    log_section_success "Rsyslog configuration applied"
    echo "${FG_GREEN}${CHECKMARK} Logging configured${RESET}"
    
    # Set up log rotation
    cat > /etc/logrotate.d/hardening << 'EOF'
/var/log/secure {
    daily
    rotate 90
    compress
    delaycompress
    notifempty
    create 0600 root root
    sharedscripts
    postrotate
        /usr/sbin/service rsyslog rotate > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log_section_success "Log rotation policy configured"
    echo "${FG_GREEN}${CHECKMARK} Log rotation: 90-day retention${RESET}"
    
    # Set appropriate permissions on log files
    chmod 640 /var/log/*.log 2>/dev/null
    chmod 640 /var/log/audit/audit.log 2>/dev/null
    
    log_section_success "Log file permissions restricted"
    echo "${FG_GREEN}${CHECKMARK} Log file permissions: 640${RESET}"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

view_system_logs() {
    clear
    draw_header
    echo "${FG_ORANGE}${BOLD}=== VIEW SYSTEM LOGS ===${RESET}"
    echo ""
    
    log_section_info "Viewing recent system logs..."
    
    echo "Recent authentication logs (last 20 lines):"
    echo "==========================================="
    tail -20 /var/log/secure 2>/dev/null || tail -20 /var/log/auth.log 2>/dev/null || echo "No logs found"
    
    echo ""
    echo "Recent system logs (last 20 lines):"
    echo "==================================="
    tail -20 /var/log/messages 2>/dev/null | head -20 || echo "No logs found"
    
    echo ""
    echo "Audit summary:"
    echo "=============="
    ausummary 2>/dev/null | head -10 || echo "Auditd not active"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

configure_external_logging() {
    clear
    draw_header
    echo "${FG_ORANGE}${BOLD}=== EXTERNAL LOGGING CONFIGURATION ===${RESET}"
    echo ""
    
    log_section_info "Configuring external logging..."
    
    echo "Setting up external syslog forwarding..."
    echo ""
    
    # Check if rsyslog is installed
    if ! dnf list installed rsyslog 2>/dev/null | grep -q "Installed"; then
        echo "Installing rsyslog..."
        dnf install -y rsyslog &>/dev/null
    fi
    
    # Backup rsyslog config
    cp /etc/rsyslog.conf "${SECTION_BACKUP_DIR}/rsyslog_conf_$(date +%Y%m%d_%H%M%S)"
    
    echo ""
    echo "Configure external logging server (optional)"
    echo "=============================================="
    read -rp "Enter external syslog server IP (leave empty to skip): " syslog_server
    
    if [ -n "$syslog_server" ]; then
        read -rp "Enter syslog server port (default 514): " syslog_port
        syslog_port=${syslog_port:-514}
        
        # Determine protocol
        echo "Select protocol:"
        echo "1) UDP (standard)"
        echo "2) TCP (reliable)"
        read -rp "Select (1-2, default 1): " protocol_choice
        
        case $protocol_choice in
            2) protocol="@@" ;;
            *) protocol="@" ;;
        esac
        
        # Add external logging rule
        cat >> /etc/rsyslog.conf << EOF

# External logging forwarding
*.* ${protocol}${syslog_server}:${syslog_port}
EOF
        
        log_section_success "External logging configured: $syslog_server:$syslog_port"
        echo "${FG_GREEN}${CHECKMARK} External logging configured${RESET}"
    else
        echo "${FG_YELLOW}⚠ External logging not configured${RESET}"
    fi
    
    # Enable local logging files
    echo ""
    echo "Local logging configuration:"
    echo "  • Auth logs: /var/log/secure"
    echo "  • System logs: /var/log/messages"
    echo "  • Kernel logs: /var/log/kern.log"
    
    # Restart rsyslog
    systemctl enable rsyslog &>/dev/null
    systemctl restart rsyslog &>/dev/null
    log_section_success "Rsyslog service restarted"
    echo "${FG_GREEN}${CHECKMARK} Rsyslog service restarted${RESET}"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

configure_hostname_resolution() {
    clear
    draw_header
    echo "${FG_ORANGE}${BOLD}=== HOSTNAME RESOLUTION ===${RESET}"
    echo ""
    
    log_section_info "Configuring hostname resolution..."
    
    echo "Setting up proper hostname/localhost separation..."
    echo ""
    
    # Backup /etc/hosts
    cp /etc/hosts "${SECTION_BACKUP_DIR}/hosts_$(date +%Y%m%d_%H%M%S)"
    
    local hostname=$(hostname)
    
    echo "Current configuration:"
    echo "  Hostname: $hostname"
    echo ""
    
    # Create proper /etc/hosts
    cat > /etc/hosts << EOF
# IPv4
127.0.0.1       localhost
127.0.0.1       localhost.localdomain

# Hostname
127.0.0.1       $hostname

# IPv6
::1             localhost
::1             localhost.localdomain
::1             $hostname
EOF
    
    log_section_success "/etc/hosts configured"
    echo "${FG_GREEN}${CHECKMARK} Proper hostname resolution configured${RESET}"
    echo ""
    echo "New /etc/hosts content:"
    cat /etc/hosts
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

submenu_audit_logs() {
init_section_logging "audit_logs"
while true; do
clear
draw_header
echo "${FG_ORANGE}${BOLD}=== AUDIT AND LOGS ===${RESET}"
echo ""
echo "${FG_ORANGE}${BOLD}╔══════════════════════════════════════════════════════╗"
echo "${FG_ORANGE}${BOLD}║   This section contains audit and logging settings   ║"
echo "${FG_ORANGE}${BOLD}║   for system actions. Auditd setup, logging          ║"
echo "${FG_ORANGE}${BOLD}║   configuration, file integrity monitoring and      ║"
echo "${FG_ORANGE}${BOLD}║   viewing system logs.                               ║"
echo "${FG_ORANGE}${BOLD}║   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ║"
echo "${FG_ORANGE}${BOLD}╚══════════════════════════════════════════════════════╝"
echo "${RESET}"
echo "1) Auditd configuration"
echo "2) Logging and monitoring"
echo "3) View system logs"
echo "4) External logging"
echo "5) Hostname resolution"
echo "6) Create section backup"
echo "7) View logs"
echo "8) Restore from backup"
echo ""
echo "0) Back"
echo ""
read -rp "Select: " choice
case $choice in
1) configure_auditd ;;
2) configure_logging ;;
3) view_system_logs ;;
4) configure_external_logging ;;
5) configure_hostname_resolution ;;
6) create_section_backup ;;
7) view_section_logs ;;
8) restore_section_backup ;;
0) break ;;
*) ;;
esac
done
}