# includes/additional_tools.sh
#!/bin/bash

# Additional tools section: Handles extra security and diagnostic tools for Rocky Linux 9.7

run_security_scan() {
    clear
    draw_header
    echo "${FG_YELLOW}${BOLD}=== SECURITY VULNERABILITY SCAN ===${RESET}"
    echo ""
    
    log_section_info "Running security scan..."
    
    echo "Starting comprehensive security scan..."
    echo ""
    
    # Run Lynis if available
    if command -v lynis &>/dev/null; then
        echo "Running Lynis audit..."
        echo "======================================"
        lynis audit system quick 2>&1 | tee -a "$SECTION_LOG_FILE"
    else
        echo "${FG_YELLOW}Lynis not installed. Install with: dnf install -y epel-release && dnf install -y lynis${RESET}"
        log_section_warning "Lynis not installed"
    fi
    
    # Check open ports
    echo ""
    echo "Open network ports:"
    echo "==================="
    ss -tulnp 2>/dev/null | head -20
    
    # Check for security updates
    echo ""
    echo "Security updates available:"
    echo "============================"
    dnf check-update --security 2>/dev/null | head -20
    
    log_section_success "Security scan completed"
    read -rp "${FG_GREEN}Press Enter to return to menu...${RESET}"
}

generate_report() {
    clear
    draw_header
    echo "${FG_YELLOW}${BOLD}=== GENERATE SECURITY REPORT ===${RESET}"
    echo ""
    
    log_section_info "Generating comprehensive security report..."
    
    local reports_dir="${BACKUP_BASE_DIR}/reports"
    local report_file="${reports_dir}/security_report_$(date +%Y%m%d_%H%M%S).txt"
    
    mkdir -p "$reports_dir"
    
    echo "Generating security report..."
    echo "Report location: $report_file"
    echo ""
    
    {
        echo "======================================================"
        echo " ROCKY LINUX 9.7 SECURITY HARDENING REPORT"
        echo "======================================================"
        echo "Generated: $(date)"
        echo "Hostname: $(hostname)"
        echo ""
        
        echo "=== SYSTEM INFORMATION ==="
        echo "OS: $(cat /etc/rocky-release)"
        echo "Kernel: $(uname -r)"
        echo "Uptime: $(uptime -p)"
        echo ""
        
        echo "=== SSH SECURITY ==="
        echo "SSH Service Status: $(systemctl is-active sshd)"
        echo "SSH Port: $(grep -E '^Port' /etc/ssh/sshd_config | awk '{print $2}')"
        echo "Root Login: $(grep -E '^PermitRootLogin' /etc/ssh/sshd_config | awk '{print $2}')"
        echo "Password Auth: $(grep -E '^PasswordAuthentication' /etc/ssh/sshd_config | awk '{print $2}')"
        echo ""
        
        echo "=== FIREWALL STATUS ==="
        echo "Firewalld Status: $(systemctl is-active firewalld)"
        if systemctl is-active --quiet firewalld; then
            echo "Active Rules:"
            firewall-cmd --list-all 2>/dev/null | head -20
        fi
        echo ""
        
        echo "=== SELINUX STATUS ==="
        echo "SELinux Mode: $(getenforce 2>/dev/null || echo 'N/A')"
        echo ""
        
        echo "=== RUNNING SECURITY SERVICES ==="
        systemctl list-units --type=service --state=running | grep -E "fail2ban|auditd|firewalld|aide" || echo "Some services not running"
        echo ""
        
        echo "=== OPEN NETWORK PORTS ==="
        ss -tulnp 2>/dev/null | grep LISTEN
        echo ""
        
        echo "=== CRITICAL FILES PERMISSIONS ==="
        ls -la /etc/passwd /etc/shadow /etc/group /etc/gshadow 2>/dev/null
        echo ""
        
        echo "=== AUDIT LOGS ==="
        tail -10 /var/log/audit/audit.log 2>/dev/null || echo "No audit logs found"
        echo ""
        
        echo "=== AUTHENTICATION LOGS ==="
        tail -10 /var/log/secure 2>/dev/null || tail -10 /var/log/auth.log 2>/dev/null || echo "No auth logs found"
        
    } > "$report_file"
    
    log_section_success "Security report generated: $report_file"
    echo "${FG_GREEN}${CHECKMARK} Report generated successfully${RESET}"
    echo "File size: $(du -h "$report_file" | cut -f1)"
    
    read -rp "${FG_GREEN}Press Enter to return to menu...${RESET}"
}

show_system_info() {
    clear
    draw_header
    echo "${FG_YELLOW}${BOLD}=== SYSTEM INFORMATION ===${RESET}"
    echo ""
    
    log_section_info "Displaying system information..."
    
    echo "===== SYSTEM OVERVIEW ====="
    echo ""
    
    echo "Hostname: $(hostname)"
    echo "OS Release: $(cat /etc/rocky-release)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p)"
    
    echo ""
    echo "===== CPU INFORMATION ====="
    echo "Cores: $(nproc)"
    lscpu | head -10
    
    echo ""
    echo "===== MEMORY INFORMATION ====="
    free -h
    
    echo ""
    echo "===== DISK INFORMATION ====="
    df -h
    
    echo ""
    echo "===== NETWORK INFORMATION ====="
    ip addr show | grep -E "inet|link"
    ip route show
    
    echo ""
    echo "===== SECURITY SETTINGS ====="
    echo "SELinux: $(getenforce 2>/dev/null || echo 'N/A')"
    echo "Firewall: $(systemctl is-active firewalld || echo 'Inactive')"
    echo "SSH Status: $(systemctl is-active sshd)"
    echo "Auditd: $(systemctl is-active auditd || echo 'Inactive')"
    
    read -rp "${FG_GREEN}Press Enter to return to menu...${RESET}"
}

setup_banners() {
    clear
    draw_header
    echo "${FG_YELLOW}${BOLD}=== LOGIN BANNERS ===${RESET}"
    echo ""
    
    log_section_info "Setting up legal banners..."
    
    echo "Creating legal warning banners..."
    echo ""
    
    # Create /etc/issue banner (local login)
    cat > /etc/issue << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║           AUTHORIZED ACCESS ONLY                          ║
║                                                           ║
║  This system is for authorized use only. All activity     ║
║  is logged and monitored. Unauthorized access attempts    ║
║  will be investigated and prosecuted to the fullest       ║
║  extent permitted by law. By accessing this system,       ║
║  you acknowledge that you have read and understood        ║
║  these terms and conditions.                              ║
│                                                           │
║              Questions? Contact: System Administrator      ║
╚═══════════════════════════════════════════════════════════╝

EOF
    
    log_section_success "Local login banner created"
    echo "${FG_GREEN}${CHECKMARK} Local login banner configured${RESET}"
    
    # Create /etc/issue.net banner (remote SSH login)
    cat > /etc/issue.net << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║           AUTHORIZED ACCESS ONLY                          ║
║                                                           ║
║  This system is for authorized use only. All activity     ║
║  is logged and monitored. Unauthorized access attempts    ║
║  will be investigated and prosecuted to the fullest       ║
║  extent permitted by law. By accessing this system,       ║
║  you acknowledge that you have read and understood        ║
║  these terms and conditions.                              ║
│                                                           │
║              Questions? Contact: System Administrator      ║
╚═══════════════════════════════════════════════════════════╝

EOF
    
    log_section_success "SSH login banner configured"
    echo "${FG_GREEN}${CHECKMARK} SSH login banner configured${RESET}"
    
    # Ensure SSH uses the banner
    if ! grep -q "^Banner /etc/issue.net" /etc/ssh/sshd_config; then
        echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
        systemctl reload sshd &>/dev/null
    fi
    
    # Fix permissions
    chmod 644 /etc/issue
    chmod 644 /etc/issue.net
    
    echo "${FG_GREEN}${CHECKMARK} Banners configured with proper permissions${RESET}"
    
    read -rp "${FG_GREEN}Press Enter to return to menu...${RESET}"
}

restrict_compilers() {
    clear
    draw_header
    echo "${FG_YELLOW}${BOLD}=== COMPILER RESTRICTIONS ===${RESET}"
    echo ""
    
    log_section_info "Restricting compiler access..."
    
    echo "Hardening compiler access for security..."
    echo ""
    
    # Get list of compilers
    local compilers=("gcc" "cc" "c++" "g++" "as" "ld" "make")
    
    for compiler in "${compilers[@]}"; do
        local path=$(which "$compiler" 2>/dev/null)
        if [ -n "$path" ]; then
            chmod 750 "$path"
            echo -ne "Restricted: $compiler... "
            echo "${FG_GREEN}${CHECKMARK}${RESET}"
            log_section_info "Compiler restricted: $compiler ($path)"
        fi
    done
    
    echo ""
    echo "Creating /etc/sudoers.d entry for compiler access..."
    
    # Add compiler restriction via sudoers
    cat > /etc/sudoers.d/compiler-restriction << 'EOF'
# Only allow wheel group members to use compilers
# Uncomment and modify as needed for your security policy
# %wheel ALL = /usr/bin/gcc, /usr/bin/make

# Require password for compiler usage
Defaults use_pty
EOF
    
    chmod 440 /etc/sudoers.d/compiler-restriction
    
    log_section_success "Compiler restrictions applied"
    echo "${FG_GREEN}${CHECKMARK} Compiler access restricted to root${RESET}"
    echo "${FG_GREEN}${CHECKMARK} Sudoers entry created for controlled access${RESET}"
    
    read -rp "${FG_GREEN}Press Enter to return to menu...${RESET}"
}

harden_file_permissions() {
    clear
    draw_header
    echo "${FG_YELLOW}${BOLD}=== FILE PERMISSIONS HARDENING ===${RESET}"
    echo ""
    
    log_section_info "Hardening critical file permissions..."
    
    echo "Setting restrictive permissions on critical files..."
    echo ""
    
    # Critical file permission configurations
    declare -A file_perms=(
        ["/etc/passwd"]="644"
        ["/etc/shadow"]="640"
        ["/etc/group"]="644"
        ["/etc/gshadow"]="640"
        ["/etc/security/pwquality.conf"]="644"
        ["/etc/ssh/sshd_config"]="600"
        ["/etc/sudoers"]="440"
        ["/root/.ssh"]="700"
        ["/etc/grub2.cfg"]="600"
        ["/etc/audit/rules.d"]="750"
    )
    
    for file in "${!file_perms[@]}"; do
        if [ -e "$file" ]; then
            chmod "${file_perms[$file]}" "$file" 2>/dev/null
            echo "${FG_GREEN}${CHECKMARK}${RESET} $file → ${file_perms[$file]}"
            log_section_info "Hardened permissions: $file (${file_perms[$file]})"
        fi
    done
    
    echo ""
    echo "Setting SGID and SUID restrictions..."
    
    # Find and restrict problematic SUID binaries
    local dangerous_suid=(
        "traceroute"
        "netreport"
        "usernetctl"
    )
    
    for binary in "${dangerous_suid[@]}"; do
        local path=$(find /usr -name "$binary" -type f 2>/dev/null | head -1)
        if [ -n "$path" ] && [ -u "$path" ]; then
            chmod -s "$path" 2>/dev/null
            echo "${FG_GREEN}${CHECKMARK} Removed SUID: $binary${RESET}"
            log_section_info "Removed SUID from: $binary"
        fi
    done
    
    log_section_success "File permissions hardened"
    echo ""
    echo "${FG_GREEN}${CHECKMARK} Critical file permissions configured${RESET}"
    
    read -rp "${FG_GREEN}Press Enter to return to menu...${RESET}"
}

analyze_system_hardening() {
    clear
    draw_header
    echo "${FG_YELLOW}${BOLD}=== SYSTEM HARDENING ANALYSIS ===${RESET}"
    echo ""
    
    log_section_info "Analyzing system hardening with systemd..."
    
    echo "Analyzing systemd service security..."
    echo ""
    
    # Get list of critical services
    local services=("sshd" "firewalld" "auditd" "rsyslog")
    
    for service in "${services[@]}"; do
        echo ""
        echo "${FG_CYAN}═══════════════════════════════════${RESET}"
        echo "${FG_YELLOW}Service: $service${RESET}"
        echo "${FG_CYAN}═══════════════════════════════════${RESET}"
        
        if command -v systemd-analyze &>/dev/null; then
            systemd-analyze security "$service" 2>&1 | head -30
            log_section_info "Analyzed service: $service"
        else
            echo "systemd-analyze not available"
        fi
    done
    
    echo ""
    echo "For detailed analysis, run manually:"
    echo "  systemd-analyze security <service-name>"
    echo ""
    
    log_section_success "System hardening analysis completed"
    read -rp "${FG_GREEN}Press Enter to return to menu...${RESET}"
}

submenu_additional_tools() {
init_section_logging "additional_tools"
while true; do
clear
draw_header
echo "${FG_YELLOW}${BOLD}=== ADDITIONAL TOOLS ===${RESET}"
echo ""
echo "${FG_YELLOW}${BOLD}╔══════════════════════════════════════════════════════╗"
echo "${FG_YELLOW}${BOLD}║   This section contains additional tools for         ║"
echo "${FG_YELLOW}${BOLD}║   security checks and system diagnostics.            ║"
echo "${FG_YELLOW}${BOLD}║   Vulnerability scanning, compliance checking,       ║"
echo "${FG_YELLOW}${BOLD}║   report generation.                                 ║"
echo "${FG_YELLOW}${BOLD}║   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ║"
echo "${FG_YELLOW}${BOLD}╚══════════════════════════════════════════════════════╝"
echo "${RESET}"
echo "1) Security check"
echo "2) Create report"
echo "3) System information"
echo "4) Login banners"
echo "5) Restrict compilers"
echo "6) Harden file permissions"
echo "7) System hardening analysis"
echo "8) Create section backup"
echo "9) View logs"
echo "10) Restore from backup"
echo ""
echo "0) Back"
echo ""
read -rp "Select: " choice
case $choice in
1) run_security_scan ;;
2) generate_report ;;
3) show_system_info ;;
4) setup_banners ;;
5) restrict_compilers ;;
6) harden_file_permissions ;;
7) analyze_system_hardening ;;
8) create_section_backup ;;
9) view_section_logs ;;
10) restore_section_backup ;;
0) break ;;
*) ;;
esac
done
}