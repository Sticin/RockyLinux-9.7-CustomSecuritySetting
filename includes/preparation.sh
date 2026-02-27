# includes/preparation.sh
#!/bin/bash

# Preparation section: Handles system preparation tasks for Rocky Linux 9.7

check_internet() {
    log_section_info "Checking internet connection..."
    if ping -c 1 8.8.8.8 &> /dev/null || ping -c 1 1.1.1.1 &> /dev/null; then
        log_section_success "Internet connection is available"
        return 0
    else
        log_section_warning "No internet connection detected"
        return 1
    fi
}

install_linpeas() {
    log_section_info "Installing linPEAS..."
    local linpeas_dir="/opt/linpeas"
    
    if [ ! -d "$linpeas_dir" ]; then
        mkdir -p "$linpeas_dir"
        log_section_info "Downloading linPEAS..."
        cd "$linpeas_dir"
        if curl -s https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh -o linpeas.sh 2>/dev/null; then
            chmod +x linpeas.sh
            log_section_success "linPEAS installed successfully"
        else
            log_section_error "Failed to download linPEAS"
            return 1
        fi
    else
        log_section_warning "linPEAS already installed at $linpeas_dir"
    fi
}

install_epel() {
    log_section_info "Installing EPEL repository..."
    
    if dnf repolist | grep -q "epel"; then
        log_section_warning "EPEL repository already installed"
        return 0
    fi
    
    if dnf install -y epel-release &>/dev/null; then
        dnf makecache &>/dev/null
        log_section_success "EPEL repository installed successfully"
        return 0
    else
        log_section_error "Failed to install EPEL repository"
        return 1
    fi
}

install_selinux_tools() {
    log_section_info "Installing SELinux tools..."
    
    local packages=("policycoreutils-python-utils" "selinux-policy-devel" "setroubleshoot")
    
    for pkg in "${packages[@]}"; do
        if ! dnf list installed "$pkg" &>/dev/null; then
            log_section_info "Installing $pkg..."
            if dnf install -y "$pkg" &>/dev/null; then
                log_section_success "$pkg installed"
            else
                log_section_warning "Failed to install $pkg"
            fi
        fi
    done
}

install_lynis() {
    log_section_info "Installing Lynis..."
    
    if command -v lynis &>/dev/null; then
        log_section_warning "Lynis already installed"
        return 0
    fi
    
    install_epel
    
    if dnf install -y lynis &>/dev/null; then
        log_section_success "Lynis installed successfully"
        return 0
    else
        log_section_error "Failed to install Lynis"
        return 1
    fi
}

install_malware_scanner() {
    log_section_info "Installing Malware Scanner (ClamAV)..."
    
    if command -v clamscan &>/dev/null; then
        log_section_warning "ClamAV already installed"
        return 0
    fi
    
    if dnf install -y clamav clamav-update &>/dev/null; then
        log_section_success "ClamAV malware scanner installed successfully"
        return 0
    else
        log_section_error "Failed to install ClamAV"
        return 1
    fi
}

check_and_install_dependencies() {
    clear
    draw_header
    echo "${FG_CYAN}${BOLD}=== CHECK AND INSTALL DEPENDENCIES ===${RESET}"
    echo ""
    
    log_section_info "Checking and installing dependencies for Rocky Linux 9.7"
    
    local essential_packages=(
        "curl"
        "wget"
        "git"
        "dnf-plugins-core"
        "python3"
        "bash-completion"
        "net-tools"
        "vim"
        "nano"
        "openssl"
        "openssh-clients"
        "firewalld"
        "aide"
        "audit"
    )
    
    echo "Installing essential packages..."
    for pkg in "${essential_packages[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            echo -ne "Installing $pkg... "
            if dnf install -y "$pkg" &>/dev/null; then
                echo "${FG_GREEN}${CHECKMARK}${RESET}"
                log_section_success "Installed: $pkg"
            else
                echo "${FG_YELLOW}${CROSSMARK}${RESET}"
                log_section_warning "Failed to install: $pkg"
            fi
        else
            echo "${FG_GREEN}${CHECKMARK}${RESET} $pkg (already installed)"
        fi
    done
    
    # Install Lynis and linPEAS
    echo ""
    echo "Installing security tools..."
    install_lynis
    install_selinux_tools
    install_malware_scanner
    
    log_section_success "Dependencies installation completed"
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

check_system_health() {
    clear
    draw_header
    echo "${FG_BLUE}${BOLD}=== CHECK SYSTEM HEALTH ===${RESET}"
    echo ""
    
    log_section_info "Running system health check..."
    
    echo "${FG_CYAN}System Information:${RESET}"
    echo "================================="
    
    # OS Version
    echo -n "OS Version: "
    cat /etc/rocky-release
    
    # Kernel Version
    echo -n "Kernel: "
    uname -r
    
    # Uptime
    echo -n "Uptime: "
    uptime -p
    
    # CPU Info
    echo -n "CPU Cores: "
    nproc
    
    # Memory
    echo -n "Total Memory: "
    free -h | grep Mem | awk '{print $2}'
    
    # Disk Space
    echo "Disk Space:"
    df -h / | tail -1
    
    # Check network connectivity
    echo ""
    echo "${FG_CYAN}Network Status:${RESET}"
    echo "================================="
    if check_internet; then
        echo "${FG_GREEN}${CHECKMARK} Internet connectivity OK${RESET}"
    else
        echo "${FG_RED}${CROSSMARK} No internet connection${RESET}"
    fi
    
    # Check important services
    echo ""
    echo "${FG_CYAN}Important Services:${RESET}"
    echo "================================="
    
    for service in firewalld auditd sshd; do
        if systemctl is-active --quiet "$service"; then
            echo "${FG_GREEN}${CHECKMARK}${RESET} $service: $(systemctl is-active $service)"
        else
            echo "${FG_YELLOW}${CROSSMARK}${RESET} $service: $(systemctl is-active $service)"
        fi
    done
    
    # Check SELinux status
    echo ""
    echo "${FG_CYAN}Security Configuration:${RESET}"
    echo "================================="
    
    if command -v getenforce &>/dev/null; then
        echo "SELinux Status: $(getenforce)"
    fi
    
    log_section_success "System health check completed"
    echo ""
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

create_backup_point() {
    clear
    draw_header
    echo "${FG_GREEN}${BOLD}=== CREATE RESTORE POINT ===${RESET}"
    echo ""
    
    log_section_info "Creating system backup point..."
    
    local backup_dir="${BACKUP_BASE_DIR}/preparation"
    local backup_file="${backup_dir}/system_backup_$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p "$backup_dir"
    
    echo "Creating system configuration backup..."
    echo "Backup location: $backup_file"
    echo ""
    
    local backup_paths=(
        "/etc/ssh/"
        "/etc/sysctl.conf"
        "/etc/security/"
        "/etc/hosts"
        "/etc/fstab"
    )
    
    for path in "${backup_paths[@]}"; do
        if [ -e "$path" ]; then
            if [ -d "$path" ]; then
                tar -czf "${backup_file}_${path//\//_}.tar.gz" "$path" 2>/dev/null && \
                echo "${FG_GREEN}${CHECKMARK}${RESET} Backed up: $path"
            else
                cp "$path" "${backup_file}_${path//\//_}" && \
                echo "${FG_GREEN}${CHECKMARK}${RESET} Backed up: $path"
            fi
        fi
    done
    
    log_section_success "System backup point created: $backup_file"
    echo ""
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

submenu_preparation() {
init_section_logging "preparation"
while true; do
clear
draw_header
echo "${FG_GREEN}${BOLD}=== SYSTEM PREPARATION ===${RESET}"
echo ""
echo "${FG_GREEN}${BOLD}╔══════════════════════════════════════════════════════╗"
echo "${FG_GREEN}${BOLD}║   This section contains preparatory actions          ║"
echo "${FG_GREEN}${BOLD}║   before security configuration. Create a backup,    ║"
echo "${FG_GREEN}${BOLD}║   check the system and install necessary packages.   ║"
echo "${FG_GREEN}${BOLD}║   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ║"
echo "${FG_GREEN}${BOLD}╚══════════════════════════════════════════════════════╝"
echo "${RESET}"
echo "1) Check system health"
echo "2) Create restore point"
echo "3) Check and install dependencies"
echo "4) Create section backup"
echo "5) View logs"
echo "6) Restore from backup"
echo ""
echo "0) Back"
echo ""
read -rp "Select: " choice
case $choice in
1) check_system_health ;;
2) create_backup_point ;;
3) check_and_install_dependencies ;;
4) create_section_backup ;;
5) view_section_logs ;;
6) restore_section_backup ;;
0) break ;;
*) ;;
esac
done
}