# includes/access_control.sh
#!/bin/bash

# Access control section: Handles user access and password policies for Rocky Linux 9.7

configure_password_policy() {
    clear
    draw_header
    echo "${FG_CYAN}${BOLD}=== PASSWORD POLICY ===${RESET}"
    echo ""
    
    log_section_info "Configuring password policy..."
    
    echo "${FG_CYAN}Password Policy Configuration:${RESET}"
    echo "=========================================="
    echo ""
    
    # Install libpwquality if not present
    if ! dnf list installed libpwquality 2>/dev/null | grep -q "Installed"; then
        dnf install -y libpwquality &>/dev/null
    fi
    
    # Backup original files
    cp /etc/pam.d/password-auth "${SECTION_BACKUP_DIR}/password-auth_$(date +%Y%m%d_%H%M%S)"
    cp /etc/pam.d/system-auth "${SECTION_BACKUP_DIR}/system-auth_$(date +%Y%m%d_%H%M%S)"
    
    # Interactive password policy settings
    local min_len=$(prompt_with_default "Minimum password length" "14")
    local max_days=$(prompt_with_default "Maximum password age (days)" "90")
    local min_days=$(prompt_with_default "Minimum password age (days)" "1")
    local warn_age=$(prompt_with_default "Warning days before expiry" "14")
    local lockout_attempts=$(prompt_with_default "Lockout after N failed attempts" "5")
    local lockout_time=$(prompt_with_default "Lockout duration (seconds)" "900")
    
    echo ""
    if prompt_yes_no "Require uppercase letters?" "yes"; then
        local ucredit="-1"
        echo "${FG_GREEN}${CHECKMARK} Uppercase required${RESET}"
    else
        local ucredit="0"
        echo "${FG_GREEN}${CHECKMARK} Uppercase optional${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Require lowercase letters?" "yes"; then
        local lcredit="-1"
        echo "${FG_GREEN}${CHECKMARK} Lowercase required${RESET}"
    else
        local lcredit="0"
        echo "${FG_GREEN}${CHECKMARK} Lowercase optional${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Require digits?" "yes"; then
        local dcredit="-1"
        echo "${FG_GREEN}${CHECKMARK} Digits required${RESET}"
    else
        local dcredit="0"
        echo "${FG_GREEN}${CHECKMARK} Digits optional${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Require special characters?" "yes"; then
        local ocredit="-1"
        echo "${FG_GREEN}${CHECKMARK} Special characters required${RESET}"
    else
        local ocredit="0"
        echo "${FG_GREEN}${CHECKMARK} Special characters optional${RESET}"
    fi
    
    # Configure password quality requirements
    cat > /etc/security/pwquality.conf << EOF
# Password quality requirements
minlen = $min_len
dcredit = $dcredit
ucredit = $ucredit
ocredit = $ocredit
lcredit = $lcredit
difok = 3
maxrepeat = 3
usercheck = 1
enforce_for_root
EOF
    
    log_section_success "Password quality configured"
    echo "${FG_GREEN}${CHECKMARK} Password quality configured${RESET}"
    
    # Configure password aging
    cat > /etc/login.defs.local << EOF
PASS_MAX_DAYS   $max_days
PASS_MIN_DAYS   $min_days
PASS_WARN_AGE   $warn_age
EOF
    
    # Apply to existing users
    grep -v "^#" /etc/login.defs.local | while read line; do
        key=$(echo "$line" | awk '{print $1}')
        val=$(echo "$line" | awk '{print $2}')
        sed -i "s/^$key.*/$key $val/" /etc/login.defs
    done
    
    log_section_success "Password aging configured"
    echo "${FG_GREEN}${CHECKMARK} Max password age: $max_days days${RESET}"
    echo "${FG_GREEN}${CHECKMARK} Min password age: $min_days day${RESET}"
    echo "${FG_GREEN}${CHECKMARK} Warning before expiry: $warn_age days${RESET}"
    
    # Configure account lockout policy
    cat > /etc/pam.d/faillock << EOF
auth required pam_faillock.so preauth silent audit deny=$lockout_attempts unlock_time=$lockout_time
EOF
    
    log_section_success "Account lockout policy configured"
    echo "${FG_GREEN}${CHECKMARK} Lockout after $lockout_attempts failed attempts${RESET}"
    echo "${FG_GREEN}${CHECKMARK} Lockout duration: $lockout_time seconds ($(($lockout_time / 60)) minutes)${RESET}"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

configure_access_policies() {
    clear
    draw_header
    echo "${FG_CYAN}${BOLD}=== ACCESS POLICIES ===${RESET}"
    echo ""
    
    log_section_info "Configuring access policies..."
    
    echo "${FG_CYAN}Access Policy Configuration:${RESET}"
    echo "=========================================="
    echo ""
    
    # Disable unnecessary user accounts
    local disabled_users=("games" "news" "uucp" "mysql" "postgres" "ntp") 
    
    if prompt_yes_no "Disable unnecessary system accounts?" "yes"; then
        for user in "${disabled_users[@]}"; do
            if id "$user" &>/dev/null; then
                usermod -L "$user" 2>/dev/null
                usermod -s /usr/sbin/nologin "$user" 2>/dev/null
                echo "${FG_GREEN}${CHECKMARK} Disabled user: $user${RESET}"
                log_section_info "Disabled user: $user"
            fi
        done
    fi
    
    echo ""
    if prompt_yes_no "Restrict su command to wheel group?" "yes"; then
        # Make sure pam_wheel.so line is not already present
        grep -q "pam_wheel.so use_uid" /etc/pam.d/su || echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su
        log_section_success "su command restricted to wheel group"
        echo "${FG_GREEN}${CHECKMARK} Only wheel group members can use su${RESET}"
    fi
    
    echo ""
    local umask_value=$(prompt_with_default "Default umask" "0027")
    sed -i "s/^umask.*/umask $umask_value/" /etc/bashrc
    sed -i "s/^umask.*/umask $umask_value/" /etc/profile
    log_section_success "Default umask set to $umask_value"
    echo "${FG_GREEN}${CHECKMARK} Default file permissions configured${RESET}"
    
    echo ""
    if prompt_yes_no "Enable session timeout?" "yes"; then
        local session_timeout=$(prompt_with_default "Session timeout in seconds" "900")
        cat > /etc/profile.d/timeout.sh << EOF
# Session timeout after inactivity
export TMOUT=$session_timeout
EOF
        chmod 644 /etc/profile.d/timeout.sh
        log_section_success "Session timeout set"
        echo "${FG_GREEN}${CHECKMARK} Inactive sessions timeout: $session_timeout seconds ($(($session_timeout / 60)) minutes)${RESET}"
    fi
    
    echo ""
    if prompt_yes_no "Configure SSH access restrictions?" "no"; then
        read -rp "${FG_CYAN}${BOLD}Enter allowed SSH users (space-separated) [leave blank to skip]: ${RESET}" ssh_users
        
        if [ -n "$ssh_users" ]; then
            cat > /etc/ssh/sshd_config.d/allow-users.conf << EOF
# Restrict SSH access to specific users
AllowUsers $ssh_users
EOF
            log_section_info "SSH access restricted to: $ssh_users"
            echo "${FG_GREEN}${CHECKMARK} SSH access policy configured${RESET}"
        else
            cat > /etc/ssh/sshd_config.d/allow-users.conf << 'EOF'
# Restrict SSH access to specific users
# Uncomment and modify to allow only specific users
# AllowUsers user1 user2
EOF
            echo "${FG_YELLOW}⚠ SSH access policy template created (configure manually)${RESET}"
        fi
    fi
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

create_user() {
    clear
    draw_header
    echo "${FG_YELLOW}${BOLD}=== CREATE NEW USER ===${RESET}"
    echo ""
    
    log_section_info "Creating new user account..."
    
    # Get username
    echo "${FG_CYAN}User Information:${RESET}"
    echo "=========================================="
    read -rp "Enter username: " username
    
    # Validate username
    if id "$username" &>/dev/null; then
        echo "${FG_RED}${CROSSMARK} User already exists!${RESET}"
        log_section_error "User creation failed: $username already exists"
        sleep 2
        return
    fi
    
    if ! [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "${FG_RED}${CROSSMARK} Invalid username! Use lowercase letters, numbers, underscore, hyphen${RESET}"
        log_section_error "Invalid username: $username"
        sleep 2
        return
    fi
    
    # Get password settings
    echo ""
    echo "${FG_CYAN}Password Configuration:${RESET}"
    echo "=========================================="
    read -rp "Enter password length (default 14): " pass_length
    pass_length=${pass_length:-14}
    
    if ! [[ "$pass_length" =~ ^[0-9]+$ ]] || [ "$pass_length" -lt 8 ]; then
        echo "${FG_RED}${CROSSMARK} Password length must be at least 8 characters${RESET}"
        pass_length=14
    fi
    
    echo ""
    echo "Password character options:"
    echo "  1) Only alphanumeric (letters + numbers)"
    echo "  2) Alphanumeric + special characters (!@#$%^&*)"
    echo "  3) All printable characters"
    read -rp "Select (1-3, default 2): " char_option
    char_option=${char_option:-2}
    
    # Generate password based on selected option
    case $char_option in
        1) password=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c "$pass_length") ;;
        2) password=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9!@#$%^&*' | head -c "$pass_length") ;;
        3) password=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?' | head -c "$pass_length") ;;
        *) password=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9!@#$%^&*' | head -c "$pass_length") ;;
    esac
    
    echo ""
    echo "${FG_YELLOW}Generated Password: ${BOLD}${FG_WHITE}$password${RESET}"
    echo ""
    read -rp "Accept this password? (y/N): " accept_pwd
    
    if [[ ! "$accept_pwd" =~ ^[Yy]$ ]]; then
        # Allow custom password
        password=""
        while [ -z "$password" ]; do
            echo ""
            read -rsp "Enter custom password: " custom_password
            echo ""
            
            if [ -z "$custom_password" ]; then
                echo "${FG_RED}${CROSSMARK} Password cannot be empty!${RESET}"
                continue
            fi
            
            read -rsp "Confirm password: " confirm_password
            echo ""
            
            if [ "$custom_password" != "$confirm_password" ]; then
                echo "${FG_RED}${CROSSMARK} Passwords do not match!${RESET}"
                continue
            fi
            
            if [ ${#custom_password} -lt "$pass_length" ]; then
                echo "${FG_YELLOW}⚠ Warning: Password is shorter than set length (${#custom_password}/$pass_length)${RESET}"
            fi
            
            password="$custom_password"
        done
    fi
    
    # Create user
    echo ""
    echo "${FG_BLUE}Creating user account...${RESET}"
    
    if useradd -m -s /bin/bash "$username" 2>/dev/null; then
        echo "${FG_GREEN}${CHECKMARK} User account created${RESET}"
        log_section_success "User account created: $username"
        
        # Set password
        echo "$username:$password" | chpasswd 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "${FG_GREEN}${CHECKMARK} Password set${RESET}"
            log_section_success "Password set for user: $username"
        else
            echo "${FG_RED}${CROSSMARK} Failed to set password${RESET}"
            log_section_error "Failed to set password for: $username"
        fi
        
        # Add user to wheel group (allow sudo)
        usermod -aG wheel "$username" 2>/dev/null
        echo "${FG_GREEN}${CHECKMARK} Added to wheel group (sudo access)${RESET}"
        log_section_info "Added $username to wheel group"
        
        # Enable SSH password authentication
        echo ""
        echo "${FG_BLUE}Configuring SSH access...${RESET}"
        
        # Backup SSH config
        cp /etc/ssh/sshd_config "${SECTION_BACKUP_DIR}/sshd_config_$(date +%Y%m%d_%H%M%S)" 2>/dev/null
        
        # Enable password authentication
        sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
        echo "${FG_GREEN}${CHECKMARK} SSH password authentication enabled${RESET}"
        log_section_info "SSH password authentication enabled"
        
        # Add user to SSH AllowUsers (if not already there)
        if grep -q "AllowUsers" /etc/ssh/sshd_config; then
            current_users=$(grep "^AllowUsers" /etc/ssh/sshd_config | cut -d' ' -f2-)
            if [[ ! " $current_users " =~ " $username " ]]; then
                sed -i "s/^AllowUsers.*/AllowUsers $current_users $username/" /etc/ssh/sshd_config
            fi
        else
            echo "AllowUsers $username" >> /etc/ssh/sshd_config
        fi
        echo "${FG_GREEN}${CHECKMARK} Added to SSH AllowUsers${RESET}"
        log_section_info "Added $username to SSH AllowUsers"
        
        # Create SSH banner
        cat > /etc/ssh/banner << 'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   # Rocky Linux 9.7 Security Hardening System           ║
║                                                          ║
║   - Unauthorized access is forbidden                     ║
║   - All activities are monitored and logged             ║
║   - Violations may result in legal consequences         ║
║                                                          ║
║   Questions? Contact system administrator               ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
        
        # Ensure banner is enabled in SSH config
        if ! grep -q "^Banner" /etc/ssh/sshd_config; then
            echo "Banner /etc/ssh/banner" >> /etc/ssh/sshd_config
        else
            sed -i 's|^#Banner.*|Banner /etc/ssh/banner|' /etc/ssh/sshd_config
            sed -i 's|^Banner.*none|Banner /etc/ssh/banner|' /etc/ssh/sshd_config
        fi
        
        echo "${FG_GREEN}${CHECKMARK} SSH banner configured${RESET}"
        log_section_success "SSH banner created and configured"
        
        # Reload SSH service
        systemctl reload sshd 2>/dev/null
        echo "${FG_GREEN}${CHECKMARK} SSH service reloaded${RESET}"
        log_section_info "SSH service reloaded"
        
        # Display created user information
        echo ""
        echo "${FG_CYAN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
        echo "${FG_GREEN}${BOLD}USER CREATED SUCCESSFULLY ${CHECKMARK}${RESET}"
        echo "${FG_CYAN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
        echo ""
        echo "${FG_YELLOW}${BOLD}User Information:${RESET}"
        echo "  ${FG_CYAN}Username:${RESET} $username"
        echo "  ${FG_CYAN}Password:${RESET} $password"
        echo "  ${FG_CYAN}Shell:${RESET} /bin/bash"
        echo "  ${FG_CYAN}Home:${RESET} /home/$username"
        echo "  ${FG_CYAN}Groups:${RESET} $(groups $username | cut -d':' -f2)"
        echo ""
        echo "${FG_YELLOW}${BOLD}SSH Access:${RESET}"
        echo "  ${FG_CYAN}Method:${RESET} Password-based authentication"
        echo "  ${FG_CYAN}Command:${RESET} ssh $username@<server_ip>"
        echo "  ${FG_CYAN}Banner:${RESET} Enabled ${CHECKMARK}"
        echo ""
        echo "${FG_RED}${BOLD}⚠ IMPORTANT:${RESET}"
        echo "  • Save the password securely"
        echo "  • User MUST change password on first login (run: passwd)"
        echo "  • SSH access enabled for this user"
        echo "  • Banner will display on SSH connection"
        echo ""
        echo "${FG_CYAN}${BOLD}═══════════════════════════════════════════════════════${RESET}"
        
        log_section_success "User $username created successfully with full SSH access"
        
    else
        echo "${FG_RED}${CROSSMARK} Failed to create user account${RESET}"
        log_section_error "User creation failed: useradd error"
    fi
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

set_user_expiration() {
    clear
    draw_header
    echo "${FG_CYAN}${BOLD}=== SET USER EXPIRATION ===${RESET}"
    echo ""
    
    log_section_info "Setting user account expiration dates..."
    
    echo "Configuring expiration dates for user accounts..."
    echo ""
    
    # Get list of users
    local users=$(cut -d: -f1 /etc/passwd | grep -v "^root$" | grep -v "^nobody$" | sort)
    
    echo "Available users:"
    echo "================"
    echo "$users"
    echo ""
    
    read -rp "Enter username to set expiration (or 'all' for all users): " target_user
    
    if [ "$target_user" == "all" ]; then
        # Set expiration for all non-system users
        echo ""
        echo "Setting expiration date for all users..."
        
        while read -r user; do
            # Skip system users
            uid=$(id -u "$user" 2>/dev/null)
            if [ "$uid" -ge 1000 ] 2>/dev/null; then
                # Set expiration date 1 year from now
                expiration_date=$(date -d "+1 year" +%Y-%m-%d)
                chage -E "$expiration_date" "$user" 2>/dev/null
                echo "${FG_GREEN}${CHECKMARK} $user: Expiration set to $expiration_date${RESET}"
                log_section_success "Set expiration for $user to $expiration_date"
            fi
        done <<< "$users"
    else
        # Set expiration for specific user
        if id "$target_user" &>/dev/null; then
            echo ""
            read -rp "Enter expiration date (YYYY-MM-DD) or days from now (e.g., +90): " expiry
            
            if [[ "$expiry" =~ ^\+ ]]; then
                # Relative date
                expiration_date=$(date -d "$expiry days" +%Y-%m-%d)
            else
                # Absolute date
                expiration_date="$expiry"
            fi
            
            # Validate date
            if date -d "$expiration_date" &>/dev/null; then
                chage -E "$expiration_date" "$target_user" 2>/dev/null
                echo ""
                echo "${FG_GREEN}${CHECKMARK} User: $target_user${RESET}"
                echo "${FG_GREEN}${CHECKMARK} Expiration set to: $expiration_date${RESET}"
                
                # Show current settings
                echo ""
                echo "Current password settings:"
                chage -l "$target_user" 2>/dev/null | head -5
                
                log_section_success "Set expiration for $target_user to $expiration_date"
            else
                echo "${FG_RED}${CROSSMARK} Invalid date format${RESET}"
                log_section_error "Invalid date format provided"
            fi
        else
            echo "${FG_RED}${CROSSMARK} User not found${RESET}"
            log_section_error "User not found: $target_user"
        fi
    fi
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

delete_user() {
    clear
    draw_header
    echo "${FG_YELLOW}${BOLD}=== DELETE USER ===${RESET}"
    echo ""
    
    log_section_info "Deleting user account..."
    
    echo "${FG_CYAN}User Information:${RESET}"
    echo "=========================================="
    read -rp "Enter username to delete: " username
    
    # Validate username exists
    if ! id "$username" &>/dev/null; then
        echo "${FG_RED}${CROSSMARK} User does not exist!${RESET}"
        log_section_error "User deletion failed: $username does not exist"
        sleep 2
        return
    fi
    
    # Don't allow deleting root
    if [ "$username" = "root" ]; then
        echo "${FG_RED}${CROSSMARK} Cannot delete root user!${RESET}"
        log_section_error "User deletion failed: cannot delete root"
        sleep 2
        return
    fi
    
    # Show user info before deletion
    echo ""
    echo "${FG_YELLOW}User details:${RESET}"
    id "$username"
    
    echo ""
    echo "${FG_RED}${BOLD}WARNING: This will permanently delete the user account!${RESET}"
    read -rp "${FG_YELLOW}Continue with deletion? (y/N): ${RESET}" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "${FG_YELLOW}User deletion cancelled${RESET}"
        log_section_info "User deletion cancelled by user"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return
    fi
    
    # Ask about home directory
    read -rp "Delete home directory? (y/N): " del_home
    
    if [[ "$del_home" =~ ^[Yy]$ ]]; then
        userdel -r "$username" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "${FG_GREEN}${CHECKMARK} User deleted with home directory${RESET}"
            log_section_success "User deleted: $username (including home directory)"
        else
            echo "${FG_RED}${CROSSMARK} Failed to delete user${RESET}"
            log_section_error "Failed to delete user: $username"
        fi
    else
        userdel "$username" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "${FG_GREEN}${CHECKMARK} User deleted (home directory preserved)${RESET}"
            log_section_success "User deleted: $username (home directory preserved)"
        else
            echo "${FG_RED}${CROSSMARK} Failed to delete user${RESET}"
            log_section_error "Failed to delete user: $username"
        fi
    fi
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

submenu_access_control() {
init_section_logging "access_control"
while true; do
clear
draw_header
echo "${FG_CYAN}${BOLD}=== ACCESS CONTROL ===${RESET}"
echo ""
echo "${FG_CYAN}${BOLD}╔══════════════════════════════════════════════════════╗"
echo "${FG_CYAN}${BOLD}║   This section contains access policies for          ║"
echo "${FG_CYAN}${BOLD}║   system users. Password complexity setup,           ║"
echo "${FG_CYAN}${BOLD}║   resource access restrictions, account locking      ║"
echo "${FG_CYAN}${BOLD}║   policies and user session control.                 ║"
echo "${FG_CYAN}${BOLD}║   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ║"
echo "${FG_CYAN}${BOLD}╚══════════════════════════════════════════════════════╝"
echo "${RESET}"
echo "1) Create user"
echo "2) Delete user"
echo "3) Password policy"
echo "4) Access policies"
echo "5) Set user expiration"
echo "6) Create section backup"
echo "7) View logs"
echo "8) Restore from backup"
echo ""
echo "0) Back"
echo ""
read -rp "Select: " choice
case $choice in
1) create_user ;;
2) delete_user ;;
3) configure_password_policy ;;
4) configure_access_policies ;;
5) set_user_expiration ;;
6) create_section_backup ;;
7) view_section_logs ;;
8) restore_section_backup ;;
0) break ;;
*) ;;
esac
done
}