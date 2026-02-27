# includes/doker.sh
#!/bin/bash

# Docker settings section: Docker installation and management for Rocky Linux 9.7

docker_install() {
    clear
    draw_header
    echo "${FG_RED}${BOLD}=== DOCKER INSTALLATION ===${RESET}"
    echo ""
    
    log_section_info "Installing/Updating Docker..."
    
    echo "Setting up Docker for Rocky Linux 9.7..."
    echo ""
    
    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        echo "${FG_GREEN}${CHECKMARK} Docker is already installed${RESET}"
        echo "Version: $(docker --version)"
        log_section_warning "Docker already installed"
    else
        echo "Installing Docker..."
        
        # Enable Docker repository
        dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo &>/dev/null
        
        # Install Docker
        if dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin &>/dev/null; then
            echo "${FG_GREEN}${CHECKMARK} Docker installed successfully${RESET}"
            log_section_success "Docker installed"
            echo "Version: $(docker --version)"
        else
            echo "${FG_RED}${CROSSMARK} Failed to install Docker${RESET}"
            log_section_error "Docker installation failed"
            return 1
        fi
    fi
    
    # Configure Docker daemon for security
    cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "icc": false,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "userns-remap": "default"
}
EOF
    
    log_section_success "Docker daemon configured for security"
    echo "${FG_GREEN}${CHECKMARK} Docker security configuration applied${RESET}"
    
    # Enable and start Docker
    systemctl enable docker &>/dev/null
    systemctl restart docker &>/dev/null
    
    log_section_success "Docker service enabled and started"
    echo "${FG_GREEN}${CHECKMARK} Docker service enabled${RESET}"
    
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

docker_service() {
    clear
    draw_header
    echo "${FG_RED}${BOLD}=== DOCKER SERVICE MANAGEMENT ===${RESET}"
    echo ""
    
    log_section_info "Checking Docker service status..."
    
    if ! command -v docker &>/dev/null; then
        echo "${FG_YELLOW}Docker is not installed${RESET}"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return 1
    fi
    
    echo "Docker Service Status:"
    echo "======================"
    
    echo -n "Status: "
    if systemctl is-active --quiet docker; then
        echo "${FG_GREEN}Running${RESET}"
    else
        echo "${FG_RED}Stopped${RESET}"
    fi
    
    echo -n "Enabled: "
    if systemctl is-enabled --quiet docker; then
        echo "${FG_GREEN}Yes${RESET}"
    else
        echo "${FG_YELLOW}No${RESET}"
    fi
    
    echo ""
    echo "Docker Info:"
    echo "============"
    docker info 2>&1 | head -20
    
    echo ""
    echo "Service Status:"
    echo "==============="
    systemctl status docker --no-pager | grep -E "Active|Loaded"
    
    log_section_info "Docker service status checked"
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

docker_containers() {
    clear
    draw_header
    echo "${FG_RED}${BOLD}=== CONTAINER MANAGEMENT ===${RESET}"
    echo ""
    
    log_section_info "Listing containers..."
    
    if ! command -v docker &>/dev/null; then
        echo "${FG_YELLOW}Docker is not installed${RESET}"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return 1
    fi
    
    echo "Running Containers:"
    echo "===================="
    docker ps 2>/dev/null || echo "No running containers"
    
    echo ""
    echo "All Containers:"
    echo "==============="
    docker ps -a 2>/dev/null || echo "No containers found"
    
    echo ""
    echo "Container Statistics:"
    echo "===================="
    docker stats --no-stream 2>/dev/null | head -10 || echo "No statistics available"
    
    log_section_info "Containers information displayed"
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

docker_images() {
    clear
    draw_header
    echo "${FG_RED}${BOLD}=== IMAGE MANAGEMENT ===${RESET}"
    echo ""
    
    log_section_info "Listing Docker images..."
    
    if ! command -v docker &>/dev/null; then
        echo "${FG_YELLOW}Docker is not installed${RESET}"
        read -rp "${FG_GREEN}Press Enter to return...${RESET}"
        return 1
    fi
    
    echo "Available Docker Images:"
    echo "========================"
    docker images 2>/dev/null || echo "No images found"
    
    echo ""
    echo "Image Disk Usage:"
    echo "================="
    docker system df 2>/dev/null || echo "Unable to get disk usage"
    
    echo ""
    echo "Docker System Prune (cleanup unused resources):"
    echo "==============================================="
    echo "Use: docker system prune -a"
    
    log_section_info "Docker images information displayed"
    read -rp "${FG_GREEN}Press Enter to return...${RESET}"
}

submenu_docker() {
init_section_logging "docker"
while true; do
clear
draw_header
echo "${FG_RED}${BOLD}=== DOCKER MANAGEMENT ===${RESET}"
echo ""
echo "${FG_RED}${BOLD}╔══════════════════════════════════════════════════════╗"
echo "${FG_RED}${BOLD}║   This section contains Docker installation,         ║"
echo "${FG_RED}${BOLD}║   service management, and container operations.      ║"
echo "${FG_RED}${BOLD}║   Manage containers, images, and Docker services.    ║"
echo "${FG_RED}${BOLD}║   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ║"
echo "${FG_RED}${BOLD}╚══════════════════════════════════════════════════════╝"
echo "${RESET}"
echo "1) Install/Update Docker"
echo "2) Docker service management"
echo "3) Manage containers"
echo "4) Manage images"
echo "5) Create section backup"
echo "6) View logs"
echo "7) Restore from backup"
echo ""
echo "0) Back"
echo ""
read -rp "Select: " choice
case $choice in
1) docker_install ;;
2) docker_service ;;
3) docker_containers ;;
4) docker_images ;;
5) create_section_backup ;;
6) view_section_logs ;;
7) restore_section_backup ;;
0) break ;;
*) ;;
esac
done
}