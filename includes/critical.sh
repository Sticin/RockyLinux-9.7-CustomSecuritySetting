# includes/critical.sh
#!/bin/bash

# Critical settings section: Handles essential security configurations for Rocky Linux 9.7

configure_ssh() {
    clear
    draw_header
    echo "${FG_RED}${BOLD}=== SSH SECURITY ===${RESET}"
    echo ""
    
    log_section_info "Configuring SSH security..."
    
    local ssh_config="/etc/ssh/sshd_config"
    local ssh_config_backup="${SECTION_BACKUP_DIR}/sshd_config_backup_$(date +%Y%m%d_%H%M%S)"
    
    # Backup original SSH config
    cp "$ssh_config" "$ssh_config_backup"
    log_section_info "SSH config backed up: $ssh_config_backup"
    
    echo ""
    echo "${FG_CYAN}SSH Configuration:${RESET}"
    echo "=========================================="
    
    # Interactive SSH configuration
    local ssh_port=$(prompt_with_default "Enter SSH port" "22")
    
    echo ""
    if prompt_yes_no "Allow password authentication?" "no"; then
        local password_auth="yes"
        echo "${FG_GREEN}${CHECKMARK} Password authentication enabled${RESET}"
    else
        local password_auth="no"
        echo "${FG_GREEN}${CHECKMARK} Password authentication disabled${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Allow public key authentication?" "yes"; then
        local pubkey_auth="yes"
        echo "${FG_GREEN}${CHECKMARK} Public key authentication enabled${RESET}"
    else
        local pubkey_auth="no"
        echo "${FG_GREEN}${CHECKMARK} Public key authentication disabled${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Permit root login?" "no"; then
        local permit_root="yes"
        echo "${FG_GREEN}${CHECKMARK} Root login enabled${RESET}"
    else
        local permit_root="no"
        echo "${FG_GREEN}${CHECKMARK} Root login disabled${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Allow X11 forwarding?" "no"; then
        local x11_forward="yes"
        echo "${FG_GREEN}${CHECKMARK} X11 forwarding enabled${RESET}"
    else
        local x11_forward="no"
        echo "${FG_GREEN}${CHECKMARK} X11 forwarding disabled${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Allow TCP forwarding?" "no"; then
        local tcp_forward="yes"
        echo "${FG_GREEN}${CHECKMARK} TCP forwarding enabled${RESET}"
    else
        local tcp_forward="no"
        echo "${FG_GREEN}${CHECKMARK} TCP forwarding disabled${RESET}"
    fi
    
    echo ""
    local max_auth_tries=$(prompt_with_default "Max authentication tries" "3")
    local max_sessions=$(prompt_with_default "Max concurrent sessions" "2")
    local client_alive_interval=$(prompt_with_default "Client alive interval (seconds)" "300")
    
    echo ""
    echo "Applying SSH security hardening..."
    echo ""
    
    # Create new SSH config with security settings
    cat > "${ssh_config}.new" << EOF
# SSH Security Hardening for Rocky Linux 9.7

# Port
Port $ssh_port

# Protocol
Protocol 2

# Host Keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication
PubkeyAuthentication $pubkey_auth
PasswordAuthentication $password_auth
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Root login
PermitRootLogin $permit_root

# X11 Forwarding 
X11Forwarding $x11_forward

# Max auth attempts and sessions
MaxAuthTries $max_auth_tries
MaxSessions $max_sessions

# Client timeout
ClientAliveInterval $client_alive_interval
ClientAliveCountMax 2

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Cipher and encryption
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org

# Disable dangerous features
AllowTcpForwarding $tcp_forward
AllowAgentForwarding no
TCPKeepAlive no
X11UseLocalhost yes

# Other security options
StrictModes yes
IgnoreRhosts yes
HostbasedAuthentication no
PermitUserEnvironment no
Compression no

# SSH Banner
Banner /etc/ssh/banner

# Allow specific users (optional, uncomment to use)
# AllowUsers user1 user2

# Subsystem
Subsystem sftp  /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO
EOF
    
    # Backup and apply new config
    if [ ! -f "$ssh_config" ]; then
        echo "${FG_RED}${CROSSMARK} Original SSH config not found${RESET}"
        log_section_error "SSH config file not found"
        return 1
    fi
    
    cp "$ssh_config" "${ssh_config}.bak"
    cp "${ssh_config}.new" "$ssh_config"
    
    # Test SSH config syntax
    if sshd -t &>/dev/null; then
        echo "${FG_GREEN}${CHECKMARK} SSH config syntax OK${RESET}"
        log_section_success "SSH configuration applied"
        
        # Create SSH banner
        echo "Authorized access only!" > /etc/ssh/banner
        
        # Restart SSH service
        systemctl restart sshd
        log_section_success "SSH service restarted"
        echo "${FG_GREEN}${CHECKMARK} SSH service restarted${RESET}"
    else
        echo "${FG_RED}${CROSSMARK} SSH config syntax error${RESET}"
        log_section_error "SSH config syntax error"
        mv "${ssh_config}.bak" "$ssh_config"
        systemctl restart sshd
    fi
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

configure_firewall() {
    clear
    draw_header
    echo "${FG_RED}${BOLD}=== FIREWALL CONFIGURATION ===${RESET}"
    echo ""
    
    log_section_info "Configuring Firewalld..."
    
    echo "${FG_CYAN}Firewall Configuration:${RESET}"
    echo "=========================================="
    
    # Убедимся, что firewalld установлен и запущен
    if ! dnf list installed firewalld 2>/dev/null | grep -q "Installed"; then
        echo "Installing firewalld..."
        dnf install -y firewalld &>/dev/null
        log_section_info "Firewalld installed"
    fi
    
    systemctl enable firewalld &>/dev/null
    systemctl start firewalld &>/dev/null
    log_section_success "Firewalld enabled and started"
    echo "${FG_GREEN}${CHECKMARK} Firewalld enabled${RESET}"
    
    # Установка зоны по умолчанию
    local zone=$(prompt_with_default "Enter default firewall zone" "public")
    firewall-cmd --set-default-zone="$zone" &>/dev/null
    log_section_info "Default zone set to $zone"
    echo "${FG_GREEN}${CHECKMARK} Default zone: $zone${RESET}"
    
    # Функция для применения изменений и показа статуса
    apply_and_show() {
        echo "Applying firewall rules..."
        firewall-cmd --reload
        echo "Current firewall rules:"
        firewall-cmd --list-all
        echo "Currently open ports:"
        firewall-cmd --list-ports
        echo ""
    }
    
    # SSH открываем всегда
    firewall-cmd --permanent --add-service=ssh
    log_section_info "SSH port added to firewall"
    echo "${FG_GREEN}${CHECKMARK} SSH port allowed${RESET}"
    apply_and_show
    
    # --- Функция для опроса службы с запросом порта и протокола ---
    prompt_service_custom() {
        local service_name="$1"
        local default_port="$2"
        
        if prompt_yes_no "Open $service_name port?" "y"; then
            local port=$(prompt_with_default "Enter port number (default $default_port)" "$default_port")
            # Проверка, что port - число
            if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                echo "${FG_RED}Invalid port number. Using default $default_port.${RESET}"
                port=$default_port
            fi
            
            # Запрос протокола с поддержкой both
            local protocol
            while true; do
                read -rp "Protocol (tcp/udp/both) [tcp]: " protocol
                protocol=${protocol:-tcp}
                case "${protocol,,}" in
                    tcp|udp)
                        firewall-cmd --permanent --add-port="$port/$protocol"
                        echo "${FG_GREEN}✓ Port $port/$protocol opened (for $service_name)${RESET}"
                        log_section_info "$service_name port $port/$protocol added"
                        break
                        ;;
                    both)
                        firewall-cmd --permanent --add-port="$port/tcp"
                        firewall-cmd --permanent --add-port="$port/udp"
                        echo "${FG_GREEN}✓ Port $port/tcp and $port/udp opened (for $service_name)${RESET}"
                        log_section_info "$service_name port $port/tcp+udp added"
                        break
                        ;;
                    *)
                        echo "${FG_RED}Invalid input. Please enter 'tcp', 'udp', or 'both'.${RESET}"
                        ;;
                esac
            done
            
            apply_and_show
        else
            echo "Skipping $service_name."
        fi
    }
    
    echo ""
    prompt_service_custom "HTTP" 80
    
    echo ""
    prompt_service_custom "HTTPS" 443
    
    echo ""
    prompt_service_custom "DNS" 53
    
    echo ""
    # Добавление дополнительных портов
    if prompt_yes_no "Open any additional custom ports?" "no"; then
        while true; do
            echo "Enter port number (or press Enter to skip, or 'done' to finish):"
            read -rp "> " custom_port
            if [[ "$custom_port" == "done" ]]; then
                echo "Finished adding ports."
                break
            fi
            if [ -z "$custom_port" ]; then
                echo "No port entered – skipping."
                break
            fi
            if [[ ! "$custom_port" =~ ^[0-9]+$ ]] || [ "$custom_port" -lt 1 ] || [ "$custom_port" -gt 65535 ]; then
                echo "${FG_RED}Invalid port number. Please enter a number between 1 and 65535.${RESET}"
                continue
            fi
            if [ "$custom_port" -lt 1024 ]; then
                echo "${FG_YELLOW}⚠ Port $custom_port is a privileged port (1-1023).${RESET}"
                if ! prompt_yes_no "Continue anyway?" "no"; then
                    continue
                fi
            fi
            local protocol=""
            while true; do
                read -rp "Protocol (tcp/udp) [tcp]: " protocol
                protocol=${protocol:-tcp}
                if [[ "$protocol" =~ ^(tcp|udp)$ ]]; then
                    break
                else
                    echo "${FG_RED}Invalid protocol. Please enter 'tcp' or 'udp'.${RESET}"
                fi
            done
            
            if firewall-cmd --permanent --add-port="$custom_port/$protocol"; then
                echo "${FG_GREEN}✓ Port $custom_port/$protocol opened.${RESET}"
                log_section_info "Custom port $custom_port/$protocol added"
                apply_and_show
            else
                echo "${FG_RED}Failed to open port $custom_port/$protocol.${RESET}"
            fi
            
            if ! prompt_yes_no "Add another port?" "no"; then
                break
            fi
        done
    fi
    
    echo ""
    if prompt_yes_no "Allow ICMP (ping)?" "yes"; then
        echo "${FG_GREEN}${CHECKMARK} ICMP enabled${RESET}"
        log_section_info "ICMP configured"
        apply_and_show
    else
        firewall-cmd --permanent --add-icmp-block=echo-request
        echo "${FG_GREEN}${CHECKMARK} ICMP disabled${RESET}"
        apply_and_show
    fi
    
    firewall-cmd --reload
    log_section_success "Firewall configuration applied"
    
    echo ""
    echo "Final firewall status:"
    echo "========================"
    echo "Active zones:"
    firewall-cmd --get-active-zones
    echo ""
    echo "Services allowed:"
    firewall-cmd --list-services
    echo ""
    echo "Ports allowed:"
    firewall-cmd --list-ports
    echo ""
    echo "Complete ruleset:"
    firewall-cmd --list-all
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

configure_fail2ban() {
    clear
    draw_header
    echo "${FG_RED}${BOLD}=== FAIL2BAN PROTECTION ===${RESET}"
    echo ""
    
    log_section_info "Installing and configuring Fail2Ban..."
    
    echo "Setting up Fail2Ban brute-force protection..."
    echo ""
    
    # Install EPEL if not installed
    if ! dnf repolist | grep -q "epel"; then
        echo "Installing EPEL repository..."
        dnf install -y epel-release &>/dev/null
    fi
    
    # Install fail2ban
    if ! dnf list installed fail2ban 2>/dev/null | grep -q "Installed"; then
        echo "Installing fail2ban..."
        dnf install -y fail2ban fail2ban-systemd &>/dev/null
        log_section_info "Fail2ban installed"
        echo "${FG_GREEN}${CHECKMARK} Fail2ban installed${RESET}"
    else
        echo "${FG_GREEN}${CHECKMARK}${RESET} fail2ban already installed"
    fi
    
    # Create jail.local configuration
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/secure

[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/secure
EOF
    
    log_section_info "Fail2ban configuration created"
    echo "${FG_GREEN}${CHECKMARK} Fail2ban configuration created${RESET}"
    
    # Enable and start fail2ban
    systemctl enable fail2ban &>/dev/null
    systemctl restart fail2ban &>/dev/null
    
    # Wait for fail2ban to fully initialize
    sleep 3
    
    # Check if fail2ban is running
    if systemctl is-active --quiet fail2ban; then
        log_section_success "Fail2ban enabled and started"
        echo "${FG_GREEN}${CHECKMARK} Fail2ban service started${RESET}"
        
        echo ""
        echo "Fail2ban status:"
        echo "================"
        fail2ban-client status 2>/dev/null
        
        echo ""
        echo "Detailed jail information:"
        echo "================"
        fail2ban-client status sshd 2>/dev/null || echo "Unable to retrieve jail details"
    else
        echo "${FG_RED}${CROSSMARK} Fail2ban failed to start${RESET}"
        log_section_error "Fail2ban service failed to start"
    fi
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

configure_updates() {
    clear
    draw_header
    echo "${FG_RED}${BOLD}=== SYSTEM UPDATES ===${RESET}"
    echo ""
    
    log_section_info "Configuring automatic system updates..."
    
    echo "Setting up automatic updates..."
    echo ""
    
    # Install dnf-automatic
    if ! dnf list installed dnf-automatic 2>/dev/null | grep -q "Installed"; then
        echo "Installing dnf-automatic..."
        dnf install -y dnf-automatic &>/dev/null
        log_section_info "dnf-automatic installed"
        echo "${FG_GREEN}${CHECKMARK} dnf-automatic installed${RESET}"
    fi
    
    # Configure dnf-automatic
    cat > /etc/dnf/automatic.conf << 'EOF'
[commands]
upgrade_type = security
apply_updates = yes
emit_via = motd

[emitters]
system_hostname = /etc/hostname
EOF
    
    log_section_info "dnf-automatic configuration updated"
    echo "${FG_GREEN}${CHECKMARK} Update policy configured${RESET}"
    
    # Enable and start dnf-automatic timer
    systemctl enable dnf-automatic.timer &>/dev/null
    systemctl start dnf-automatic.timer &>/dev/null
    log_section_success "Automatic updates enabled"
    echo "${FG_GREEN}${CHECKMARK} Automatic updates enabled${RESET}"
    
    echo ""
    echo "Checking current updates..."
    echo "============================"
    dnf check-update | head -20
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

submenu_critical() {
init_section_logging "critical"
while true; do
clear
draw_header
echo "${FG_RED}${BOLD}=== CRITICAL SETTINGS ===${RESET}"
echo ""
echo "${FG_RED}${BOLD}╔══════════════════════════════════════════════════════╗"
echo "${FG_RED}${BOLD}║   This section contains the most important and       ║"
echo "${FG_RED}${BOLD}║   critical system security settings.                 ║"
echo "${FG_RED}${BOLD}║   SSH protection, Firewalld - basic incoming traffic ║"
echo "${FG_RED}${BOLD}║   filtering, brute-force protection.                 ║"
echo "${FG_RED}${BOLD}║   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ║"
echo "${FG_RED}${BOLD}╚══════════════════════════════════════════════════════╝"
echo "${RESET}"
echo "1) SSH security"
echo "2) Firewall configuration"
echo "3) Fail2Ban protection"
echo "4) System updates"
echo "5) Create section backup"
echo "6) View logs"
echo "7) Restore from backup"
echo ""
echo "0) Back"
echo ""
read -rp "Select: " choice
case $choice in
1) configure_ssh ;;
2) configure_firewall ;;
3) configure_fail2ban ;;
4) configure_updates ;;
5) create_section_backup ;;
6) view_section_logs ;;
7) restore_section_backup ;;
0) break ;;
*) ;;
esac
done
}