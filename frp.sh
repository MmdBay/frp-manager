#!/bin/bash

# =============================================================================
# FRP Professional Management System
# =============================================================================
# Advanced FRP Installation, Configuration, and Management Script
# Supports both Server (Iran) and Client (Foreign) modes
# Features: Multi-server management, Load balancing, Monitoring, Backup
# Author: System Administrator
# Version: 2.0 Professional
# License: MIT
# =============================================================================

# Global variables
SCRIPT_VERSION="2.0"
SCRIPT_NAME="FRP Professional Manager"
CONFIG_DIR="/etc/frp"
BACKUP_DIR="/var/backups/frp"
LOG_DIR="/var/log/frp"
MONITORING_DIR="/var/lib/frp/monitoring"
DASHBOARD_DIR="/var/www/frp-dashboard"
SSL_DIR="/etc/ssl/frp"

set -e

# Advanced color scheme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Function to print colored output with timestamps
print_status() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $1"
}

print_debug() {
    echo -e "${GRAY}[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG]${NC} $1"
}

print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    FRP Professional Manager                   ║${NC}"
    echo -e "${CYAN}║                        Version ${SCRIPT_VERSION}                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_footer() {
    echo
    echo -e "${GRAY}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GRAY}║                    System Information                        ║${NC}"
    echo -e "${GRAY}║  OS: $(uname -s) $(uname -r) | Uptime: $(uptime -p) | Load: $(uptime | awk -F'load average:' '{print $2}') ║${NC}"
    echo -e "${GRAY}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Function to check system requirements
check_system_requirements() {
    print_status "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Check available memory
    local mem_available=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [[ $mem_available -lt 512 ]]; then
        print_warning "Low memory available: ${mem_available}MB (Recommended: 512MB+)"
    fi
    
    # Check available disk space
    local disk_available=$(df / | awk 'NR==2{printf "%.0f", $4/1024}')
    if [[ $disk_available -lt 1024 ]]; then
        print_warning "Low disk space: ${disk_available}MB (Recommended: 1GB+)"
    fi
    
    print_success "System requirements check completed"
}

# Function to initialize directories
initialize_directories() {
    print_status "Initializing FRP directory structure..."
    
    local dirs=("$CONFIG_DIR" "$BACKUP_DIR" "$LOG_DIR" "$MONITORING_DIR" "$DASHBOARD_DIR" "$SSL_DIR")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            chmod 755 "$dir"
        fi
    done
    
    # Create log files
    touch "$LOG_DIR/operations.log" 2>/dev/null || true
    touch "$LOG_DIR/access.log" 2>/dev/null || true
    touch "$LOG_DIR/error.log" 2>/dev/null || true
    
    print_success "Directory structure initialized"
}

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [[ -f /etc/debian_version ]]; then
        OS=Debian
        VER=$(cat /etc/debian_version)
    elif [[ -f /etc/redhat-release ]]; then
        OS=RedHat
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    print_status "Detected OS: $OS $VER"
}

# Function to resolve package manager locks
resolve_package_locks() {
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        if [[ -f /var/lib/apt/lists/lock ]] || [[ -f /var/lib/dpkg/lock ]]; then
            print_warning "Package manager locks detected. Attempting to resolve..."
            pkill -f "apt-get|apt" || true
            sleep 2
            
            if ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
                rm -f /var/lib/apt/lists/lock
            fi
            
            if ! fuser /var/lib/dpkg/lock >/dev/null 2>&1; then
                rm -f /var/lib/dpkg/lock
            fi
            
            if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
                rm -f /var/lib/dpkg/lock-frontend
            fi
            
            print_status "Package manager locks resolved"
        fi
    fi
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt update
        apt install -y wget curl unzip systemd
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Rocky"* ]]; then
        yum update -y
        yum install -y wget curl unzip systemd
    else
        print_error "Unsupported OS: $OS"
        exit 1
    fi
    
    print_success "Dependencies installed successfully"
}

# Function to get proxy settings
get_proxy_settings() {
    echo -e "${YELLOW}Do you want to use a proxy for downloads? (y/n):${NC}"
    read -r use_proxy
    
    if [[ $use_proxy =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Enter proxy type (http/socks5):${NC}"
        read -r proxy_type
        
        echo -e "${YELLOW}Enter proxy address (e.g., 127.0.0.1:8080):${NC}"
        read -r proxy_address
        
        echo -e "${YELLOW}Enter proxy username (leave empty if none):${NC}"
        read -r proxy_user
        
        if [[ -n "$proxy_user" ]]; then
            echo -e "${YELLOW}Enter proxy password:${NC}"
            read -s proxy_pass
            echo
        fi
        
        # Set proxy environment variables
        if [[ "$proxy_type" == "http" ]]; then
            export http_proxy="http://$proxy_address"
            export https_proxy="http://$proxy_address"
        elif [[ "$proxy_type" == "socks5" ]]; then
            export http_proxy="socks5://$proxy_address"
            export https_proxy="socks5://$proxy_address"
        fi
        
        # Add authentication if provided
        if [[ -n "$proxy_user" ]]; then
            if [[ "$proxy_type" == "http" ]]; then
                export http_proxy="http://$proxy_user:$proxy_pass@$proxy_address"
                export https_proxy="http://$proxy_user:$proxy_pass@$proxy_address"
            elif [[ "$proxy_type" == "socks5" ]]; then
                export http_proxy="socks5://$proxy_user:$proxy_pass@$proxy_address"
                export https_proxy="socks5://$proxy_user:$proxy_pass@$proxy_address"
            fi
        fi
        
        print_status "Proxy configured: $proxy_type://$proxy_address"
    fi
}

# Function to download FRP
download_frp() {
    print_status "Downloading FRP..."
    
    # Determine architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="arm"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Try to get latest FRP version
    FRP_VERSION=""
    if command -v jq >/dev/null 2>&1; then
        FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | jq -r '.tag_name' 2>/dev/null)
    else
        FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
    fi
    
    # Fallback to known working version if detection fails
    if [[ -z "$FRP_VERSION" ]] || [[ "$FRP_VERSION" == "null" ]]; then
        FRP_VERSION="v0.58.0"
        print_warning "Could not detect latest version, using fallback: $FRP_VERSION"
    else
        print_status "Latest FRP version: $FRP_VERSION"
    fi
    
    # Try different URL formats
    FRP_URLS=(
        "https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/frp_${FRP_VERSION}_linux_${ARCH}.tar.gz"
        "https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/frp_${FRP_VERSION:1}_linux_${ARCH}.tar.gz"
    )
    
    # Try to download from different URLs
    DOWNLOAD_SUCCESS=false
    for FRP_URL in "${FRP_URLS[@]}"; do
        print_status "Trying URL: $FRP_URL"
        if wget -O /tmp/frp.tar.gz "$FRP_URL" 2>/dev/null; then
            DOWNLOAD_SUCCESS=true
            print_status "Download successful from: $FRP_URL"
            break
        fi
    done
    
    if [[ "$DOWNLOAD_SUCCESS" == false ]]; then
        print_error "Failed to download FRP from all URLs"
        print_error "Please check your internet connection and proxy settings"
        exit 1
    fi
    
    # Extract FRP
    if ! tar -xzf /tmp/frp.tar.gz -C /tmp; then
        print_error "Failed to extract FRP archive"
        exit 1
    fi
    
    # Find the extracted directory
    FRP_DIR=$(find /tmp -maxdepth 1 -name "frp*" -type d | head -1)
    if [[ -z "$FRP_DIR" ]]; then
        print_error "Could not find extracted FRP directory"
        exit 1
    fi
    
    print_status "Found FRP directory: $FRP_DIR"
    
    # Install FRP
    mkdir -p /usr/local/bin/frp
    cp -r "$FRP_DIR"/* /usr/local/bin/frp/
    chmod +x /usr/local/bin/frp/frps
    chmod +x /usr/local/bin/frp/frpc
    
    # Create symlinks
    ln -sf /usr/local/bin/frp/frps /usr/local/bin/frps
    ln -sf /usr/local/bin/frp/frpc /usr/local/bin/frpc
    
    # Clean up
    rm -rf /tmp/frp.tar.gz /tmp/frp_*
    
    print_success "FRP installed successfully"
}

# Function to install Nginx
install_nginx() {
    print_status "Installing Nginx..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt install -y nginx
        systemctl enable nginx
        systemctl start nginx
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Rocky"* ]]; then
        yum install -y nginx
        systemctl enable nginx
        systemctl start nginx
    fi
    
    print_success "Nginx installed and started"
}

# Function to configure FRP server with advanced settings
configure_frp_server() {
    print_status "Configuring FRP server with advanced settings..."
    
    # Get server configuration
    echo -e "${YELLOW}Enter FRP server bind port (default: 7000):${NC}"
    read -r bind_port
    bind_port=${bind_port:-7000}
    
    echo -e "${YELLOW}Enter dashboard port (default: 7500):${NC}"
    read -r dashboard_port
    dashboard_port=${dashboard_port:-7500}
    
    echo -e "${YELLOW}Enter dashboard username (default: admin):${NC}"
    read -r dashboard_user
    dashboard_user=${dashboard_user:-admin}
    
    echo -e "${YELLOW}Enter dashboard password:${NC}"
    read -s dashboard_pass
    echo
    
    echo -e "${YELLOW}Enter authentication token (default: random):${NC}"
    read -r auth_token
    if [[ -z "$auth_token" ]]; then
        auth_token=$(openssl rand -hex 16)
    fi
    
    # Advanced configuration options
    echo -e "${YELLOW}Configure advanced settings? (y/n):${NC}"
    read -r advanced_config
    
    if [[ $advanced_config =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Enter max pool count (default: 5):${NC}"
        read -r max_pool_count
        max_pool_count=${max_pool_count:-5}
        
        echo -e "${YELLOW}Enter max ports per client (default: 0 = unlimited):${NC}"
        read -r max_ports_per_client
        max_ports_per_client=${max_ports_per_client:-0}
        
        echo -e "${YELLOW}Enter authentication timeout in seconds (default: 900):${NC}"
        read -r auth_timeout
        auth_timeout=${auth_timeout:-900}
        
        echo -e "${YELLOW}Enter heartbeat timeout in seconds (default: 90):${NC}"
        read -r heartbeat_timeout
        heartbeat_timeout=${heartbeat_timeout:-90}
        
        echo -e "${YELLOW}Enter user connection timeout in seconds (default: 10):${NC}"
        read -r user_conn_timeout
        user_conn_timeout=${user_conn_timeout:-10}
        
        echo -e "${YELLOW}Enable TCP multiplexing? (y/n, default: y):${NC}"
        read -r tcp_mux
        tcp_mux=${tcp_mux:-y}
        
        echo -e "${YELLOW}Enter subdomain host (leave empty if not using subdomains):${NC}"
        read -r subdomain_host
        
        echo -e "${YELLOW}Enter custom domains (comma separated, leave empty if none):${NC}"
        read -r custom_domains
        
        echo -e "${YELLOW}Enable detailed logging? (y/n, default: y):${NC}"
        read -r detailed_logging
        detailed_logging=${detailed_logging:-y}
        
        echo -e "${YELLOW}Enter log level (debug/info/warn/error, default: info):${NC}"
        read -r log_level
        log_level=${log_level:-info}
        
        echo -e "${YELLOW}Enter log max days (default: 7):${NC}"
        read -r log_max_days
        log_max_days=${log_max_days:-7}
    else
        # Default advanced settings
        max_pool_count=5
        max_ports_per_client=0
        auth_timeout=900
        heartbeat_timeout=90
        user_conn_timeout=10
        tcp_mux="y"
        subdomain_host=""
        custom_domains=""
        detailed_logging="y"
        log_level="info"
        log_max_days=7
    fi
    
    # Create advanced FRP server config
    cat > /usr/local/bin/frp/frps.ini << EOF
[common]
bind_port = $bind_port
dashboard_port = $dashboard_port
dashboard_user = $dashboard_user
dashboard_pwd = $dashboard_pass
authentication_method = token
token = $auth_token
log_file = /var/log/frps.log
log_level = $log_level
log_max_days = $log_max_days

# Advanced performance settings
max_pool_count = $max_pool_count
max_ports_per_client = $max_ports_per_client
authentication_timeout = $auth_timeout
heartbeat_timeout = $heartbeat_timeout
user_conn_timeout = $user_conn_timeout
EOF

    # Add TCP multiplexing if enabled
    if [[ $tcp_mux =~ ^[Yy]$ ]]; then
        echo "tcp_mux = true" >> /usr/local/bin/frp/frps.ini
    fi
    
    # Add subdomain host if specified
    if [[ -n "$subdomain_host" ]]; then
        echo "subdomain_host = $subdomain_host" >> /usr/local/bin/frp/frps.ini
    fi
    
    # Add custom domains if specified
    if [[ -n "$custom_domains" ]]; then
        echo "custom_domains = $custom_domains" >> /usr/local/bin/frp/frps.ini
    fi
    
    # Add detailed logging if enabled
    if [[ $detailed_logging =~ ^[Yy]$ ]]; then
        echo "detailed_errors_to_client = true" >> /usr/local/bin/frp/frps.ini
    fi
    
    # Create systemd service for FRP server
    cat > /etc/systemd/system/frps.service << EOF
[Unit]
Description=FRP Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/frps -c /usr/local/bin/frp/frps.ini
Restart=always
RestartSec=5s
StandardOutput=journal
StandardError=journal

# Performance optimizations
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start FRP server
    systemctl daemon-reload
    systemctl enable frps
    systemctl start frps
    
    # Create log file
    touch /var/log/frps.log
    chmod 644 /var/log/frps.log
    
    print_success "FRP server configured with advanced settings"
    print_status "Dashboard available at: http://$(hostname -I | awk '{print $1}'):$dashboard_port"
    print_status "Authentication token: $auth_token"
    print_status "Bind port: $bind_port"
    print_status "Max pool count: $max_pool_count"
    print_status "Heartbeat timeout: ${heartbeat_timeout}s"
}

# Function to configure FRP client with advanced settings
configure_frp_client() {
    print_status "Configuring FRP client with advanced settings..."
    
    # Get client configuration
    echo -e "${YELLOW}Enter FRP server IP address:${NC}"
    read -r server_ip
    
    echo -e "${YELLOW}Enter FRP server port (default: 7000):${NC}"
    read -r server_port
    server_port=${server_port:-7000}
    
    echo -e "${YELLOW}Enter authentication token:${NC}"
    read -r auth_token
    
    echo -e "${YELLOW}Enter local service port to expose (e.g., 80, 443, 22):${NC}"
    read -r local_port
    
    echo -e "${YELLOW}Enter remote port on server (leave empty for auto):${NC}"
    read -r remote_port
    
    echo -e "${YELLOW}Enter service name (e.g., web, ssh):${NC}"
    read -r service_name
    
    # Advanced configuration options
    echo -e "${YELLOW}Configure advanced settings? (y/n):${NC}"
    read -r advanced_config
    
    if [[ $advanced_config =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Enter protocol (tcp/udp, default: tcp):${NC}"
        read -r protocol
        protocol=${protocol:-tcp}
        
        echo -e "${YELLOW}Enter local IP (default: 127.0.0.1):${NC}"
        read -r local_ip
        local_ip=${local_ip:-127.0.0.1}
        
        echo -e "${YELLOW}Enable TCP multiplexing? (y/n, default: y):${NC}"
        read -r tcp_mux
        tcp_mux=${tcp_mux:-y}
        
        echo -e "${YELLOW}Enter heartbeat interval in seconds (default: 30):${NC}"
        read -r heartbeat_interval
        heartbeat_interval=${heartbeat_interval:-30}
        
        echo -e "${YELLOW}Enter heartbeat timeout in seconds (default: 90):${NC}"
        read -r heartbeat_timeout
        heartbeat_timeout=${heartbeat_timeout:-90}
        
        echo -e "${YELLOW}Enter login fail exit (y/n, default: y):${NC}"
        read -r login_fail_exit
        login_fail_exit=${login_fail_exit:-y}
        
        echo -e "${YELLOW}Enter max retry count (default: 3):${NC}"
        read -r max_retry_count
        max_retry_count=${max_retry_count:-3}
        
        echo -e "${YELLOW}Enter retry interval in seconds (default: 10):${NC}"
        read -r retry_interval
        retry_interval=${retry_interval:-10}
        
        echo -e "${YELLOW}Enter log level (debug/info/warn/error, default: info):${NC}"
        read -r log_level
        log_level=${log_level:-info}
        
        echo -e "${YELLOW}Enter log max days (default: 7):${NC}"
        read -r log_max_days
        log_max_days=${log_max_days:-7}
        
        echo -e "${YELLOW}Enable compression? (y/n, default: y):${NC}"
        read -r compression
        compression=${compression:-y}
        
        echo -e "${YELLOW}Enable encryption? (y/n, default: y):${NC}"
        read -r encryption
        encryption=${encryption:-y}
        
        echo -e "${YELLOW}Enter bandwidth limit in MB/s (leave empty for unlimited):${NC}"
        read -r bandwidth_limit
        
        echo -e "${YELLOW}Enter proxy settings (http/socks5, leave empty if none):${NC}"
        read -r proxy_type
        
        if [[ -n "$proxy_type" ]]; then
            echo -e "${YELLOW}Enter proxy address (e.g., 127.0.0.1:8080):${NC}"
            read -r proxy_address
        fi
    else
        # Default advanced settings
        protocol="tcp"
        local_ip="127.0.0.1"
        tcp_mux="y"
        heartbeat_interval=30
        heartbeat_timeout=90
        login_fail_exit="y"
        max_retry_count=3
        retry_interval=10
        log_level="info"
        log_max_days=7
        compression="y"
        encryption="y"
        bandwidth_limit=""
        proxy_type=""
        proxy_address=""
    fi
    
    # Create advanced FRP client config
    cat > /usr/local/bin/frp/frpc.ini << EOF
[common]
server_addr = $server_ip
server_port = $server_port
authentication_method = token
token = $auth_token
log_file = /var/log/frpc.log
log_level = $log_level
log_max_days = $log_max_days

# Advanced connection settings
heartbeat_interval = $heartbeat_interval
heartbeat_timeout = $heartbeat_timeout
login_fail_exit = $login_fail_exit
max_retry_count = $max_retry_count
retry_interval = $retry_interval
EOF

    # Add TCP multiplexing if enabled
    if [[ $tcp_mux =~ ^[Yy]$ ]]; then
        echo "tcp_mux = true" >> /usr/local/bin/frp/frpc.ini
    fi
    
    # Add compression if enabled
    if [[ $compression =~ ^[Yy]$ ]]; then
        echo "use_compression = true" >> /usr/local/bin/frp/frpc.ini
    fi
    
    # Add encryption if enabled
    if [[ $encryption =~ ^[Yy]$ ]]; then
        echo "use_encryption = true" >> /usr/local/bin/frp/frpc.ini
    fi
    
    # Add bandwidth limit if specified
    if [[ -n "$bandwidth_limit" ]]; then
        echo "bandwidth_limit = $bandwidth_limit" >> /usr/local/bin/frp/frpc.ini
    fi
    
    # Add proxy settings if specified
    if [[ -n "$proxy_type" ]] && [[ -n "$proxy_address" ]]; then
        echo "protocol = $proxy_type" >> /usr/local/bin/frp/frpc.ini
        echo "proxy_addr = $proxy_address" >> /usr/local/bin/frp/frpc.ini
    fi
    
    # Add service configuration
    echo "" >> /usr/local/bin/frp/frpc.ini
    echo "[$service_name]" >> /usr/local/bin/frp/frpc.ini
    echo "type = $protocol" >> /usr/local/bin/frp/frpc.ini
    echo "local_ip = $local_ip" >> /usr/local/bin/frp/frpc.ini
    echo "local_port = $local_port" >> /usr/local/bin/frp/frpc.ini
    
    if [[ -n "$remote_port" ]]; then
        echo "remote_port = $remote_port" >> /usr/local/bin/frp/frpc.ini
    fi
    
    # Add advanced service settings
    echo "use_compression = $compression" >> /usr/local/bin/frp/frpc.ini
    echo "use_encryption = $encryption" >> /usr/local/bin/frp/frpc.ini
    
    # Create systemd service for FRP client
    cat > /etc/systemd/system/frpc.service << EOF
[Unit]
Description=FRP Client
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/frpc -c /usr/local/bin/frp/frpc.ini
Restart=always
RestartSec=5s
StandardOutput=journal
StandardError=journal

# Performance optimizations
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start FRP client
    systemctl daemon-reload
    systemctl enable frpc
    systemctl start frpc
    
    # Create log file
    touch /var/log/frpc.log
    chmod 644 /var/log/frpc.log
    
    print_success "FRP client configured with advanced settings"
    print_status "Service '$service_name' exposed on port $local_port"
    print_status "Protocol: $protocol"
    print_status "Heartbeat interval: ${heartbeat_interval}s"
    print_status "Compression: $compression"
    print_status "Encryption: $encryption"
}

# Function to show status
show_status() {
    print_status "Checking FRP services status..."
    
    if systemctl is-active --quiet frps; then
        print_status "FRP Server: ${GREEN}Running${NC}"
    else
        print_status "FRP Server: ${RED}Not running${NC}"
    fi
    
    if systemctl is-active --quiet frpc; then
        print_status "FRP Client: ${GREEN}Running${NC}"
    else
        print_status "FRP Client: ${RED}Not running${NC}"
    fi
    
    if systemctl is-active --quiet nginx; then
        print_status "Nginx: ${GREEN}Running${NC}"
    else
        print_status "Nginx: ${RED}Not running${NC}"
    fi
}

# Function to show logs
show_logs() {
    echo -e "${YELLOW}Select log type:${NC}"
    echo "1) FRP Server logs (real-time)"
    echo "2) FRP Client logs (real-time)"
    echo "3) FRP Server logs (last 50 lines)"
    echo "4) FRP Client logs (last 50 lines)"
    echo "5) Nginx logs"
    echo "6) System logs for FRP services"
    echo "7) Back to main menu"
    
    read -r log_choice
    
    case $log_choice in
        1)
            print_status "Showing FRP Server logs (real-time) - Press Ctrl+C to stop"
            journalctl -u frps -f
            ;;
        2)
            print_status "Showing FRP Client logs (real-time) - Press Ctrl+C to stop"
            journalctl -u frpc -f
            ;;
        3)
            print_status "Showing last 50 lines of FRP Server logs"
            journalctl -u frps -n 50 --no-pager
            ;;
        4)
            print_status "Showing last 50 lines of FRP Client logs"
            journalctl -u frpc -n 50 --no-pager
            ;;
        5)
            print_status "Showing Nginx logs"
            journalctl -u nginx -n 50 --no-pager
            ;;
        6)
            print_status "Showing system logs for FRP services"
            journalctl | grep -i frp | tail -50
            ;;
        7)
            return
            ;;
        *)
            print_error "Invalid choice"
            return
            ;;
    esac
}

# Function to check connections
check_connections() {
    print_status "Checking FRP connections..."
    
    # Check if FRP server is running
    if systemctl is-active --quiet frps; then
        print_status "FRP Server is running"
        
        # Get server config to find dashboard port
        if [[ -f /usr/local/bin/frp/frps.ini ]]; then
            DASHBOARD_PORT=$(grep "dashboard_port" /usr/local/bin/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')
            if [[ -n "$DASHBOARD_PORT" ]]; then
                print_status "Dashboard available at: http://$(hostname -I | awk '{print $1}'):$DASHBOARD_PORT"
            fi
        fi
        
        # Check active connections
        print_status "Active connections to FRP server:"
        ss -tuln | grep :7000 || print_warning "No connections on port 7000"
        
    else
        print_error "FRP Server is not running"
    fi
    
    # Check if FRP client is running
    if systemctl is-active --quiet frpc; then
        print_status "FRP Client is running"
        
        # Check client connections
        print_status "FRP Client connections:"
        ss -tuln | grep :7000 || print_warning "No client connections"
        
    else
        print_error "FRP Client is not running"
    fi
    
    # Check network connectivity
    print_status "Network connectivity check:"
    if [[ -f /usr/local/bin/frp/frpc.ini ]]; then
        SERVER_IP=$(grep "server_addr" /usr/local/bin/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')
        SERVER_PORT=$(grep "server_port" /usr/local/bin/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')
        
        if [[ -n "$SERVER_IP" ]] && [[ -n "$SERVER_PORT" ]]; then
            print_status "Testing connection to server: $SERVER_IP:$SERVER_PORT"
            if timeout 5 bash -c "</dev/tcp/$SERVER_IP/$SERVER_PORT"; then
                print_status "Connection to server: ${GREEN}SUCCESS${NC}"
            else
                print_error "Connection to server: ${RED}FAILED${NC}"
            fi
        fi
    fi
}

# Function to configure firewall
configure_firewall() {
    print_status "Configuring firewall..."
    
    if command -v ufw >/dev/null 2>&1; then
        # Ubuntu/Debian UFW
        ufw allow 7000/tcp
        ufw allow 7500/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        print_status "UFW firewall configured"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # CentOS/RHEL firewalld
        firewall-cmd --permanent --add-port=7000/tcp
        firewall-cmd --permanent --add-port=7500/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --reload
        print_status "Firewalld configured"
    else
        print_warning "No firewall manager detected. Please configure firewall manually."
    fi
}

# Function to troubleshoot connection issues
troubleshoot_connection() {
    print_status "Troubleshooting FRP connection issues..."
    
    echo -e "${YELLOW}Select troubleshooting option:${NC}"
    echo "1) Fix token mismatch"
    echo "2) Check and fix configuration files"
    echo "3) Reset client configuration"
    echo "4) Test network connectivity"
    echo "5) View detailed error logs"
    echo "6) Back to main menu"
    
    read -r troubleshoot_choice
    
    case $troubleshoot_choice in
        1)
            print_status "Fixing token mismatch..."
            
            if [[ -f /usr/local/bin/frp/frps.ini ]] && [[ -f /usr/local/bin/frp/frpc.ini ]]; then
                SERVER_TOKEN=$(grep 'token' /usr/local/bin/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')
                CLIENT_TOKEN=$(grep 'token' /usr/local/bin/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')
                
                print_status "Server token: $SERVER_TOKEN"
                print_status "Client token: $CLIENT_TOKEN"
                
                if [[ "$SERVER_TOKEN" != "$CLIENT_TOKEN" ]]; then
                    print_warning "Tokens don't match! Updating client token to match server..."
                    sed -i "s/token = .*/token = $SERVER_TOKEN/" /usr/local/bin/frp/frpc.ini
                    print_status "Client token updated"
                    
                    if systemctl is-active --quiet frpc; then
                        systemctl restart frpc
                        print_status "FRP client restarted"
                    fi
                else
                    print_status "Tokens already match"
                fi
            else
                print_error "Configuration files not found"
            fi
            ;;
        2)
            print_status "Checking configuration files..."
            
            if [[ -f /usr/local/bin/frp/frps.ini ]]; then
                echo -e "${YELLOW}Server configuration:${NC}"
                cat /usr/local/bin/frp/frps.ini
            fi
            
            if [[ -f /usr/local/bin/frp/frpc.ini ]]; then
                echo -e "${YELLOW}Client configuration:${NC}"
                cat /usr/local/bin/frp/frpc.ini
            fi
            ;;
        3)
            print_status "Resetting client configuration..."
            echo -e "${YELLOW}This will remove the current client configuration. Continue? (y/n):${NC}"
            read -r reset_confirm
            
            if [[ $reset_confirm =~ ^[Yy]$ ]]; then
                rm -f /usr/local/bin/frp/frpc.ini
                systemctl stop frpc 2>/dev/null || true
                systemctl disable frpc 2>/dev/null || true
                print_status "Client configuration reset. Please reconfigure using option 2"
            fi
            ;;
        4)
            print_status "Testing network connectivity..."
            
            if [[ -f /usr/local/bin/frp/frpc.ini ]]; then
                SERVER_IP=$(grep "server_addr" /usr/local/bin/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')
                SERVER_PORT=$(grep "server_port" /usr/local/bin/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')
                
                if [[ -n "$SERVER_IP" ]] && [[ -n "$SERVER_PORT" ]]; then
                    print_status "Testing connection to server: $SERVER_IP:$SERVER_PORT"
                    if timeout 5 bash -c "</dev/tcp/$SERVER_IP/$SERVER_PORT"; then
                        print_status "Connection to server: ${GREEN}SUCCESS${NC}"
                    else
                        print_error "Connection to server: ${RED}FAILED${NC}"
                    fi
                fi
            else
                print_error "Client configuration not found"
            fi
            ;;
        5)
            print_status "Showing detailed error logs..."
            journalctl -u frpc -n 100 --no-pager | grep -E "(ERROR|WARNING|FAILED)"
            ;;
        6)
            return
            ;;
        *)
            print_error "Invalid choice"
            return
            ;;
    esac
}

# Function for quick installation
quick_installation() {
    print_status "Quick installation mode - Auto-detecting configuration..."
    
    # Detect if this is a server or client based on network configuration
    local public_ip=$(curl -s ifconfig.me 2>/dev/null || echo "")
    local local_ip=$(hostname -I | awk '{print $1}')
    
    if [[ -n "$public_ip" ]] && [[ "$public_ip" != "$local_ip" ]]; then
        print_status "Detected public IP: $public_ip - Installing as SERVER"
        get_proxy_settings
        install_dependencies
        download_frp
        install_nginx
        configure_frp_server
        configure_firewall
        show_status
    else
        print_status "No public IP detected - Installing as CLIENT"
        get_proxy_settings
        install_dependencies
        download_frp
        configure_frp_client
        show_status
    fi
}

# Function to edit advanced FRP server configuration
edit_advanced_server_config() {
    print_status "Editing Advanced FRP Server Configuration..."
    
    if [[ ! -f /usr/local/bin/frp/frps.ini ]]; then
        print_error "FRP server configuration file not found"
        return
    fi
    
    echo -e "${YELLOW}Current server configuration:${NC}"
    cat /usr/local/bin/frp/frps.ini
    
    echo -e "\n${YELLOW}What would you like to edit?${NC}"
    echo "1) Basic settings (ports, auth)"
    echo "2) Performance settings (pool, timeouts)"
    echo "3) Network settings (TCP mux, domains)"
    echo "4) Logging settings"
    echo "5) Edit entire file manually"
    echo "6) Optimize for high performance"
    echo "7) Optimize for stability"
    echo "8) Back to main menu"
    
    read -r edit_choice
    
    case $edit_choice in
        1)
            edit_basic_server_settings
            ;;
        2)
            edit_performance_server_settings
            ;;
        3)
            edit_network_server_settings
            ;;
        4)
            edit_logging_server_settings
            ;;
        5)
            if command -v nano >/dev/null 2>&1; then
                nano /usr/local/bin/frp/frps.ini
            elif command -v vim >/dev/null 2>&1; then
                vim /usr/local/bin/frp/frps.ini
            else
                print_error "No text editor found. Please install nano or vim"
                return
            fi
            ;;
        6)
            optimize_server_for_performance
            ;;
        7)
            optimize_server_for_stability
            ;;
        8)
            return
            ;;
        *)
            print_error "Invalid choice"
            return
            ;;
    esac
    
    # Restart FRP server if it's running
    if systemctl is-active --quiet frps; then
        print_status "Restarting FRP server..."
        systemctl restart frps
    fi
}

# Function to edit advanced FRP client configuration
edit_advanced_client_config() {
    print_status "Editing Advanced FRP Client Configuration..."
    
    if [[ ! -f /usr/local/bin/frp/frpc.ini ]]; then
        print_error "FRP client configuration file not found"
        return
    fi
    
    echo -e "${YELLOW}Current client configuration:${NC}"
    cat /usr/local/bin/frp/frpc.ini
    
    echo -e "\n${YELLOW}What would you like to edit?${NC}"
    echo "1) Basic settings (server, auth)"
    echo "2) Connection settings (heartbeat, retry)"
    echo "3) Performance settings (compression, encryption)"
    echo "4) Service settings (protocols, ports)"
    echo "5) Logging settings"
    echo "6) Edit entire file manually"
    echo "7) Optimize for high performance"
    echo "8) Optimize for stability"
    echo "9) Back to main menu"
    
    read -r edit_choice
    
    case $edit_choice in
        1)
            edit_basic_client_settings
            ;;
        2)
            edit_connection_client_settings
            ;;
        3)
            edit_performance_client_settings
            ;;
        4)
            edit_service_client_settings
            ;;
        5)
            edit_logging_client_settings
            ;;
        6)
            if command -v nano >/dev/null 2>&1; then
                nano /usr/local/bin/frp/frpc.ini
            elif command -v vim >/dev/null 2>&1; then
                vim /usr/local/bin/frp/frpc.ini
            else
                print_error "No text editor found. Please install nano or vim"
                return
            fi
            ;;
        7)
            optimize_client_for_performance
            ;;
        8)
            optimize_client_for_stability
            ;;
        9)
            return
            ;;
        *)
            print_error "Invalid choice"
            return
            ;;
    esac
    
    # Restart FRP client if it's running
    if systemctl is-active --quiet frpc; then
        print_status "Restarting FRP client..."
        systemctl restart frpc
    fi
}

# Function to optimize server for high performance
optimize_server_for_performance() {
    print_status "Optimizing server for high performance..."
    
    # Backup current config
    cp /usr/local/bin/frp/frps.ini /usr/local/bin/frp/frps.ini.backup
    
    # Add performance optimizations
    cat >> /usr/local/bin/frp/frps.ini << EOF

# High Performance Optimizations
max_pool_count = 20
max_ports_per_client = 0
authentication_timeout = 1800
heartbeat_timeout = 60
user_conn_timeout = 5
tcp_mux = true
EOF
    
    print_success "Server optimized for high performance"
    print_status "Increased pool count, reduced timeouts, enabled TCP multiplexing"
}

# Function to optimize server for stability
optimize_server_for_stability() {
    print_status "Optimizing server for stability..."
    
    # Backup current config
    cp /usr/local/bin/frp/frps.ini /usr/local/bin/frp/frps.ini.backup
    
    # Add stability optimizations
    cat >> /usr/local/bin/frp/frps.ini << EOF

# Stability Optimizations
max_pool_count = 10
max_ports_per_client = 5
authentication_timeout = 3600
heartbeat_timeout = 120
user_conn_timeout = 30
tcp_mux = true
EOF
    
    print_success "Server optimized for stability"
    print_status "Conservative pool count, increased timeouts, enabled TCP multiplexing"
}

# Function to optimize client for high performance
optimize_client_for_performance() {
    print_status "Optimizing client for high performance..."
    
    # Backup current config
    cp /usr/local/bin/frp/frpc.ini /usr/local/bin/frp/frpc.ini.backup
    
    # Add performance optimizations
    cat >> /usr/local/bin/frp/frpc.ini << EOF

# High Performance Optimizations
heartbeat_interval = 10
heartbeat_timeout = 30
login_fail_exit = false
max_retry_count = 5
retry_interval = 5
tcp_mux = true
use_compression = true
use_encryption = true
EOF
    
    print_success "Client optimized for high performance"
    print_status "Reduced heartbeat intervals, increased retry count, enabled compression/encryption"
}

# Function to optimize client for stability
optimize_client_for_stability() {
    print_status "Optimizing client for stability..."
    
    # Backup current config
    cp /usr/local/bin/frp/frpc.ini /usr/local/bin/frp/frpc.ini.backup
    
    # Add stability optimizations
    cat >> /usr/local/bin/frp/frpc.ini << EOF

# Stability Optimizations
heartbeat_interval = 60
heartbeat_timeout = 180
login_fail_exit = true
max_retry_count = 10
retry_interval = 30
tcp_mux = true
use_compression = false
use_encryption = true
EOF
    
    print_success "Client optimized for stability"
    print_status "Increased heartbeat intervals, conservative retry settings, disabled compression"
}

# Function to show advanced status
show_advanced_status() {
    print_status "Advanced FRP Status Information..."
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Advanced FRP Status                       ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    
    # Service status
    echo -e "${WHITE}Service Status:${NC}"
    if systemctl is-active --quiet frps; then
        echo -e "  FRP Server: ${GREEN}Running${NC}"
        echo -e "  Uptime: $(systemctl show frps --property=ActiveEnterTimestamp | cut -d= -f2)"
    else
        echo -e "  FRP Server: ${RED}Not running${NC}"
    fi
    
    if systemctl is-active --quiet frpc; then
        echo -e "  FRP Client: ${GREEN}Running${NC}"
        echo -e "  Uptime: $(systemctl show frpc --property=ActiveEnterTimestamp | cut -d= -f2)"
    else
        echo -e "  FRP Client: ${RED}Not running${NC}"
    fi
    
    # Connection statistics
    echo -e "${WHITE}Connection Statistics:${NC}"
    local connections=$(ss -tuln | grep :7000 | wc -l)
    echo -e "  Active connections: $connections"
    
    # Performance metrics
    echo -e "${WHITE}Performance Metrics:${NC}"
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    echo -e "  CPU Usage: ${cpu_usage}%"
    echo -e "  Memory Usage: ${mem_usage}%"
    
    # Network statistics
    echo -e "${WHITE}Network Statistics:${NC}"
    if [[ -f /usr/local/bin/frp/frps.ini ]]; then
        local bind_port=$(grep "bind_port" /usr/local/bin/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')
        local dashboard_port=$(grep "dashboard_port" /usr/local/bin/frp/frps.ini | cut -d'=' -f2 | tr -d ' ')
        echo -e "  Bind Port: $bind_port"
        echo -e "  Dashboard Port: $dashboard_port"
    fi
    
    if [[ -f /usr/local/bin/frp/frpc.ini ]]; then
        local server_addr=$(grep "server_addr" /usr/local/bin/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')
        local server_port=$(grep "server_port" /usr/local/bin/frp/frpc.ini | cut -d'=' -f2 | tr -d ' ')
        echo -e "  Server Address: $server_addr:$server_port"
    fi
    
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Function for connection optimization wizard
connection_optimization_wizard() {
    print_status "FRP Connection Optimization Wizard"
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Connection Optimization Wizard                  ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${WHITE}This wizard will help you optimize your FRP connection based on:${NC}"
    echo -e "  • Network conditions (latency, bandwidth)"
    echo -e "  • Usage requirements (performance vs stability)"
    echo -e "  • Server resources"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "${YELLOW}Select your primary requirement:${NC}"
    echo "1) High Performance (Low latency, high throughput)"
    echo "2) High Stability (Reliable connection, fault tolerance)"
    echo "3) Balanced (Good performance and stability)"
    echo "4) Custom optimization"
    echo "5) Back to main menu"
    
    read -r opt_choice
    
    case $opt_choice in
        1)
            optimize_for_high_performance
            ;;
        2)
            optimize_for_high_stability
            ;;
        3)
            optimize_for_balanced
            ;;
        4)
            custom_optimization
            ;;
        5)
            return
            ;;
        *)
            print_error "Invalid choice"
            return
            ;;
    esac
}

# Function to optimize for high performance
optimize_for_high_performance() {
    print_status "Optimizing for High Performance..."
    
    echo -e "${YELLOW}Detecting network conditions...${NC}"
    
    # Test network latency
    local latency=$(ping -c 3 8.8.8.8 2>/dev/null | tail -1 | awk '{print $4}' | cut -d'/' -f2)
    if [[ -z "$latency" ]]; then
        latency=100
    fi
    
    print_status "Network latency: ${latency}ms"
    
    # Optimize server
    if [[ -f /usr/local/bin/frp/frps.ini ]]; then
        print_status "Optimizing server configuration..."
        
        # Backup current config
        cp /usr/local/bin/frp/frps.ini /usr/local/bin/frp/frps.ini.backup.$(date +%Y%m%d_%H%M%S)
        
        # High performance server settings
        sed -i '/^# High Performance Optimizations/d' /usr/local/bin/frp/frps.ini
        sed -i '/^max_pool_count =/d' /usr/local/bin/frp/frps.ini
        sed -i '/^heartbeat_timeout =/d' /usr/local/bin/frp/frps.ini
        sed -i '/^user_conn_timeout =/d' /usr/local/bin/frp/frps.ini
        
        cat >> /usr/local/bin/frp/frps.ini << EOF

# High Performance Optimizations
max_pool_count = 25
max_ports_per_client = 0
authentication_timeout = 1800
heartbeat_timeout = 30
user_conn_timeout = 3
tcp_mux = true
EOF
        
        print_success "Server optimized for high performance"
    fi
    
    # Optimize client
    if [[ -f /usr/local/bin/frp/frpc.ini ]]; then
        print_status "Optimizing client configuration..."
        
        # Backup current config
        cp /usr/local/bin/frp/frpc.ini /usr/local/bin/frp/frpc.ini.backup.$(date +%Y%m%d_%H%M%S)
        
        # High performance client settings
        sed -i '/^# High Performance Optimizations/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^heartbeat_interval =/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^heartbeat_timeout =/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^max_retry_count =/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^retry_interval =/d' /usr/local/bin/frp/frpc.ini
        
        cat >> /usr/local/bin/frp/frpc.ini << EOF

# High Performance Optimizations
heartbeat_interval = 5
heartbeat_timeout = 15
login_fail_exit = false
max_retry_count = 10
retry_interval = 2
tcp_mux = true
use_compression = true
use_encryption = true
EOF
        
        print_success "Client optimized for high performance"
    fi
    
    # Restart services
    if systemctl is-active --quiet frps; then
        systemctl restart frps
        print_status "FRP server restarted"
    fi
    
    if systemctl is-active --quiet frpc; then
        systemctl restart frpc
        print_status "FRP client restarted"
    fi
    
    print_success "High performance optimization completed!"
    print_status "Settings applied:"
    print_status "  • Reduced heartbeat intervals"
    print_status "  • Increased pool count"
    print_status "  • Enabled compression and encryption"
    print_status "  • Faster retry mechanism"
}

# Function to optimize for high stability
optimize_for_high_stability() {
    print_status "Optimizing for High Stability..."
    
    # Optimize server
    if [[ -f /usr/local/bin/frp/frps.ini ]]; then
        print_status "Optimizing server configuration..."
        
        # Backup current config
        cp /usr/local/bin/frp/frps.ini /usr/local/bin/frp/frps.ini.backup.$(date +%Y%m%d_%H%M%S)
        
        # High stability server settings
        sed -i '/^# High Stability Optimizations/d' /usr/local/bin/frp/frps.ini
        sed -i '/^max_pool_count =/d' /usr/local/bin/frp/frps.ini
        sed -i '/^heartbeat_timeout =/d' /usr/local/bin/frp/frps.ini
        sed -i '/^user_conn_timeout =/d' /usr/local/bin/frp/frps.ini
        
        cat >> /usr/local/bin/frp/frps.ini << EOF

# High Stability Optimizations
max_pool_count = 8
max_ports_per_client = 3
authentication_timeout = 3600
heartbeat_timeout = 180
user_conn_timeout = 60
tcp_mux = true
EOF
        
        print_success "Server optimized for high stability"
    fi
    
    # Optimize client
    if [[ -f /usr/local/bin/frp/frpc.ini ]]; then
        print_status "Optimizing client configuration..."
        
        # Backup current config
        cp /usr/local/bin/frp/frpc.ini /usr/local/bin/frp/frpc.ini.backup.$(date +%Y%m%d_%H%M%S)
        
        # High stability client settings
        sed -i '/^# High Stability Optimizations/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^heartbeat_interval =/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^heartbeat_timeout =/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^max_retry_count =/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^retry_interval =/d' /usr/local/bin/frp/frpc.ini
        
        cat >> /usr/local/bin/frp/frpc.ini << EOF

# High Stability Optimizations
heartbeat_interval = 90
heartbeat_timeout = 300
login_fail_exit = true
max_retry_count = 15
retry_interval = 60
tcp_mux = true
use_compression = false
use_encryption = true
EOF
        
        print_success "Client optimized for high stability"
    fi
    
    # Restart services
    if systemctl is-active --quiet frps; then
        systemctl restart frps
        print_status "FRP server restarted"
    fi
    
    if systemctl is-active --quiet frpc; then
        systemctl restart frpc
        print_status "FRP client restarted"
    fi
    
    print_success "High stability optimization completed!"
    print_status "Settings applied:"
    print_status "  • Increased heartbeat intervals"
    print_status "  • Conservative pool count"
    print_status "  • Disabled compression for stability"
    print_status "  • Robust retry mechanism"
}

# Function to optimize for balanced performance
optimize_for_balanced() {
    print_status "Optimizing for Balanced Performance..."
    
    # Optimize server
    if [[ -f /usr/local/bin/frp/frps.ini ]]; then
        print_status "Optimizing server configuration..."
        
        # Backup current config
        cp /usr/local/bin/frp/frps.ini /usr/local/bin/frp/frps.ini.backup.$(date +%Y%m%d_%H%M%S)
        
        # Balanced server settings
        sed -i '/^# Balanced Optimizations/d' /usr/local/bin/frp/frps.ini
        sed -i '/^max_pool_count =/d' /usr/local/bin/frp/frps.ini
        sed -i '/^heartbeat_timeout =/d' /usr/local/bin/frp/frps.ini
        sed -i '/^user_conn_timeout =/d' /usr/local/bin/frp/frps.ini
        
        cat >> /usr/local/bin/frp/frps.ini << EOF

# Balanced Optimizations
max_pool_count = 15
max_ports_per_client = 0
authentication_timeout = 1800
heartbeat_timeout = 90
user_conn_timeout = 10
tcp_mux = true
EOF
        
        print_success "Server optimized for balanced performance"
    fi
    
    # Optimize client
    if [[ -f /usr/local/bin/frp/frpc.ini ]]; then
        print_status "Optimizing client configuration..."
        
        # Backup current config
        cp /usr/local/bin/frp/frpc.ini /usr/local/bin/frp/frpc.ini.backup.$(date +%Y%m%d_%H%M%S)
        
        # Balanced client settings
        sed -i '/^# Balanced Optimizations/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^heartbeat_interval =/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^heartbeat_timeout =/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^max_retry_count =/d' /usr/local/bin/frp/frpc.ini
        sed -i '/^retry_interval =/d' /usr/local/bin/frp/frpc.ini
        
        cat >> /usr/local/bin/frp/frpc.ini << EOF

# Balanced Optimizations
heartbeat_interval = 30
heartbeat_timeout = 90
login_fail_exit = true
max_retry_count = 5
retry_interval = 15
tcp_mux = true
use_compression = true
use_encryption = true
EOF
        
        print_success "Client optimized for balanced performance"
    fi
    
    # Restart services
    if systemctl is-active --quiet frps; then
        systemctl restart frps
        print_status "FRP server restarted"
    fi
    
    if systemctl is-active --quiet frpc; then
        systemctl restart frpc
        print_status "FRP client restarted"
    fi
    
    print_success "Balanced optimization completed!"
    print_status "Settings applied:"
    print_status "  • Moderate heartbeat intervals"
    print_status "  • Balanced pool count"
    print_status "  • Enabled compression and encryption"
    print_status "  • Moderate retry mechanism"
}

# Function for custom optimization
custom_optimization() {
    print_status "Custom Optimization Setup..."
    
    echo -e "${YELLOW}Enter your network latency in milliseconds (default: 50):${NC}"
    read -r latency
    latency=${latency:-50}
    
    echo -e "${YELLOW}Enter your bandwidth in Mbps (default: 100):${NC}"
    read -r bandwidth
    bandwidth=${bandwidth:-100}
    
    echo -e "${YELLOW}Select optimization focus:${NC}"
    echo "1) Performance (60%) / Stability (40%)"
    echo "2) Performance (40%) / Stability (60%)"
    echo "3) Performance (50%) / Stability (50%)"
    
    read -r focus_choice
    
    case $focus_choice in
        1)
            # Performance focused
            heartbeat_interval=$((latency / 10))
            heartbeat_timeout=$((latency * 2))
            max_retry_count=8
            retry_interval=5
            compression="true"
            ;;
        2)
            # Stability focused
            heartbeat_interval=$((latency * 2))
            heartbeat_timeout=$((latency * 6))
            max_retry_count=12
            retry_interval=30
            compression="false"
            ;;
        3)
            # Balanced
            heartbeat_interval=$((latency * 1.5))
            heartbeat_timeout=$((latency * 4))
            max_retry_count=10
            retry_interval=15
            compression="true"
            ;;
        *)
            print_error "Invalid choice, using balanced settings"
            heartbeat_interval=$((latency * 1.5))
            heartbeat_timeout=$((latency * 4))
            max_retry_count=10
            retry_interval=15
            compression="true"
            ;;
    esac
    
    # Apply custom settings
    if [[ -f /usr/local/bin/frp/frpc.ini ]]; then
        print_status "Applying custom client settings..."
        
        # Backup current config
        cp /usr/local/bin/frp/frpc.ini /usr/local/bin/frp/frpc.ini.backup.$(date +%Y%m%d_%H%M%S)
        
        # Update settings
        sed -i "s/^heartbeat_interval = .*/heartbeat_interval = $heartbeat_interval/" /usr/local/bin/frp/frpc.ini
        sed -i "s/^heartbeat_timeout = .*/heartbeat_timeout = $heartbeat_timeout/" /usr/local/bin/frp/frpc.ini
        sed -i "s/^max_retry_count = .*/max_retry_count = $max_retry_count/" /usr/local/bin/frp/frpc.ini
        sed -i "s/^retry_interval = .*/retry_interval = $retry_interval/" /usr/local/bin/frp/frpc.ini
        sed -i "s/^use_compression = .*/use_compression = $compression/" /usr/local/bin/frp/frpc.ini
        
        print_success "Custom client settings applied"
    fi
    
    # Restart client
    if systemctl is-active --quiet frpc; then
        systemctl restart frpc
        print_status "FRP client restarted with custom settings"
    fi
    
    print_success "Custom optimization completed!"
    print_status "Applied settings based on:"
    print_status "  • Network latency: ${latency}ms"
    print_status "  • Bandwidth: ${bandwidth}Mbps"
    print_status "  • Heartbeat interval: ${heartbeat_interval}s"
    print_status "  • Heartbeat timeout: ${heartbeat_timeout}s"
}

# Function to remove FRP services and cleanup
remove_frp_services() {
    print_status "FRP Removal and Cleanup"
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    FRP Removal Options                        ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${WHITE}Select removal option:${NC}"
    echo "1) Stop and disable services only"
    echo "2) Remove services and configurations"
    echo "3) Complete removal (services + files + logs)"
    echo "4) Nuclear option (everything + system cleanup)"
    echo "5) Back to main menu"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    read -r remove_choice
    
    case $remove_choice in
        1)
            stop_disable_services
            ;;
        2)
            remove_services_configs
            ;;
        3)
            complete_removal
            ;;
        4)
            nuclear_removal
            ;;
        5)
            return
            ;;
        *)
            print_error "Invalid choice"
            return
            ;;
    esac
}

# Function to stop and disable services only
stop_disable_services() {
    print_status "Stopping and disabling FRP services..."
    
    # Stop and disable FRP server
    if systemctl is-active --quiet frps; then
        systemctl stop frps
        print_status "FRP server stopped"
    fi
    
    if systemctl is-enabled --quiet frps; then
        systemctl disable frps
        print_status "FRP server disabled"
    fi
    
    # Stop and disable FRP client
    if systemctl is-active --quiet frpc; then
        systemctl stop frpc
        print_status "FRP client stopped"
    fi
    
    if systemctl is-enabled --quiet frpc; then
        systemctl disable frpc
        print_status "FRP client disabled"
    fi
    
    # Stop and disable monitoring if exists
    if systemctl is-active --quiet frp-monitor.timer; then
        systemctl stop frp-monitor.timer
        systemctl disable frp-monitor.timer
        print_status "FRP monitoring stopped and disabled"
    fi
    
    print_success "All FRP services stopped and disabled"
}

# Function to remove services and configurations
remove_services_configs() {
    print_status "Removing FRP services and configurations..."
    
    # Stop and disable services first
    stop_disable_services
    
    # Remove systemd service files
    if [[ -f /etc/systemd/system/frps.service ]]; then
        rm -f /etc/systemd/system/frps.service
        print_status "FRP server service file removed"
    fi
    
    if [[ -f /etc/systemd/system/frpc.service ]]; then
        rm -f /etc/systemd/system/frpc.service
        print_status "FRP client service file removed"
    fi
    
    if [[ -f /etc/systemd/system/frp-monitor.service ]]; then
        rm -f /etc/systemd/system/frp-monitor.service
        print_status "FRP monitoring service file removed"
    fi
    
    if [[ -f /etc/systemd/system/frp-monitor.timer ]]; then
        rm -f /etc/systemd/system/frp-monitor.timer
        print_status "FRP monitoring timer file removed"
    fi
    
    # Remove configuration files
    if [[ -f /usr/local/bin/frp/frps.ini ]]; then
        rm -f /usr/local/bin/frp/frps.ini
        print_status "FRP server configuration removed"
    fi
    
    if [[ -f /usr/local/bin/frp/frpc.ini ]]; then
        rm -f /usr/local/bin/frp/frpc.ini
        print_status "FRP client configuration removed"
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "FRP services and configurations removed"
}

# Function for complete removal
complete_removal() {
    print_status "Complete FRP removal..."
    
    echo -e "${YELLOW}This will remove all FRP files, configurations, and logs. Continue? (y/n):${NC}"
    read -r confirm_removal
    
    if [[ ! $confirm_removal =~ ^[Yy]$ ]]; then
        print_status "Removal cancelled"
        return
    fi
    
    # Remove services and configs first
    remove_services_configs
    
    # Remove FRP binaries
    if [[ -d /usr/local/bin/frp ]]; then
        rm -rf /usr/local/bin/frp
        print_status "FRP binaries removed"
    fi
    
    # Remove symlinks
    if [[ -L /usr/local/bin/frps ]]; then
        rm -f /usr/local/bin/frps
        print_status "FRP server symlink removed"
    fi
    
    if [[ -L /usr/local/bin/frpc ]]; then
        rm -f /usr/local/bin/frpc
        print_status "FRP client symlink removed"
    fi
    
    # Remove log files
    if [[ -f /var/log/frps.log ]]; then
        rm -f /var/log/frps.log
        print_status "FRP server log removed"
    fi
    
    if [[ -f /var/log/frpc.log ]]; then
        rm -f /var/log/frpc.log
        print_status "FRP client log removed"
    fi
    
    # Remove FRP directories
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        print_status "FRP config directory removed"
    fi
    
    if [[ -d "$BACKUP_DIR" ]]; then
        rm -rf "$BACKUP_DIR"
        print_status "FRP backup directory removed"
    fi
    
    if [[ -d "$LOG_DIR" ]]; then
        rm -rf "$LOG_DIR"
        print_status "FRP log directory removed"
    fi
    
    if [[ -d "$MONITORING_DIR" ]]; then
        rm -rf "$MONITORING_DIR"
        print_status "FRP monitoring directory removed"
    fi
    
    if [[ -d "$DASHBOARD_DIR" ]]; then
        rm -rf "$DASHBOARD_DIR"
        print_status "FRP dashboard directory removed"
    fi
    
    if [[ -d "$SSL_DIR" ]]; then
        rm -rf "$SSL_DIR"
        print_status "FRP SSL directory removed"
    fi
    
    print_success "Complete FRP removal finished"
}

# Function for nuclear removal (everything + system cleanup)
nuclear_removal() {
    print_status "Nuclear FRP removal..."
    
    echo -e "${RED}⚠️  WARNING: This will remove EVERYTHING related to FRP! ⚠️${NC}"
    echo -e "${RED}This includes:${NC}"
    echo -e "  • All FRP files and directories"
    echo -e "  • All configurations and backups"
    echo -e "  • All logs and monitoring data"
    echo -e "  • Firewall rules related to FRP"
    echo -e "  • Nginx configurations for FRP dashboard"
    echo -e "  • System optimizations"
    echo
    echo -e "${YELLOW}Type 'NUCLEAR' to confirm complete removal:${NC}"
    read -r nuclear_confirm
    
    if [[ "$nuclear_confirm" != "NUCLEAR" ]]; then
        print_status "Nuclear removal cancelled"
        return
    fi
    
    # Complete removal first
    complete_removal
    
    # Remove firewall rules
    print_status "Removing firewall rules..."
    
    if command -v ufw >/dev/null 2>&1; then
        ufw delete allow 7000/tcp 2>/dev/null || true
        ufw delete allow 7500/tcp 2>/dev/null || true
        print_status "UFW rules removed"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --remove-port=7000/tcp 2>/dev/null || true
        firewall-cmd --permanent --remove-port=7500/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
        print_status "Firewalld rules removed"
    fi
    
    # Remove Nginx configurations
    if [[ -f /etc/nginx/sites-enabled/frp-dashboard ]]; then
        rm -f /etc/nginx/sites-enabled/frp-dashboard
        print_status "Nginx FRP dashboard site removed"
    fi
    
    if [[ -f /etc/nginx/sites-available/frp-dashboard ]]; then
        rm -f /etc/nginx/sites-available/frp-dashboard
        print_status "Nginx FRP dashboard config removed"
    fi
    
    # Reload Nginx if it's running
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
        print_status "Nginx reloaded"
    fi
    
    # Remove any remaining FRP processes
    pkill -f "frps" 2>/dev/null || true
    pkill -f "frpc" 2>/dev/null || true
    print_status "Any remaining FRP processes killed"
    
    # Clean up system optimizations
    print_status "Cleaning up system optimizations..."
    
    # Remove any FRP-related cron jobs
    crontab -l 2>/dev/null | grep -v "frp" | crontab - 2>/dev/null || true
    print_status "FRP cron jobs removed"
    
    # Clean up any FRP-related environment variables
    unset FRP_VERSION FRP_URL FRP_DIR 2>/dev/null || true
    
    print_success "Nuclear removal completed!"
    print_status "All FRP traces have been removed from the system"
}

# Function to show removal status
show_removal_status() {
    print_status "FRP Installation Status Check..."
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    FRP Installation Status                   ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    
    # Check binaries
    echo -e "${WHITE}Binaries:${NC}"
    if [[ -f /usr/local/bin/frps ]]; then
        echo -e "  FRP Server: ${GREEN}Installed${NC}"
    else
        echo -e "  FRP Server: ${RED}Not installed${NC}"
    fi
    
    if [[ -f /usr/local/bin/frpc ]]; then
        echo -e "  FRP Client: ${GREEN}Installed${NC}"
    else
        echo -e "  FRP Client: ${RED}Not installed${NC}"
    fi
    
    # Check services
    echo -e "${WHITE}Services:${NC}"
    if systemctl is-active --quiet frps; then
        echo -e "  FRP Server Service: ${GREEN}Running${NC}"
    elif systemctl is-enabled --quiet frps; then
        echo -e "  FRP Server Service: ${YELLOW}Disabled${NC}"
    else
        echo -e "  FRP Server Service: ${RED}Not installed${NC}"
    fi
    
    if systemctl is-active --quiet frpc; then
        echo -e "  FRP Client Service: ${GREEN}Running${NC}"
    elif systemctl is-enabled --quiet frpc; then
        echo -e "  FRP Client Service: ${YELLOW}Disabled${NC}"
    else
        echo -e "  FRP Client Service: ${RED}Not installed${NC}"
    fi
    
    # Check configurations
    echo -e "${WHITE}Configurations:${NC}"
    if [[ -f /usr/local/bin/frp/frps.ini ]]; then
        echo -e "  Server Config: ${GREEN}Exists${NC}"
    else
        echo -e "  Server Config: ${RED}Not found${NC}"
    fi
    
    if [[ -f /usr/local/bin/frp/frpc.ini ]]; then
        echo -e "  Client Config: ${GREEN}Exists${NC}"
    else
        echo -e "  Client Config: ${RED}Not found${NC}"
    fi
    
    # Check directories
    echo -e "${WHITE}Directories:${NC}"
    if [[ -d "$CONFIG_DIR" ]]; then
        echo -e "  Config Directory: ${GREEN}Exists${NC}"
    else
        echo -e "  Config Directory: ${RED}Not found${NC}"
    fi
    
    if [[ -d "$LOG_DIR" ]]; then
        echo -e "  Log Directory: ${GREEN}Exists${NC}"
    else
        echo -e "  Log Directory: ${RED}Not found${NC}"
    fi
    
    # Check firewall rules
    echo -e "${WHITE}Firewall Rules:${NC}"
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "7000/tcp"; then
            echo -e "  UFW Rules: ${GREEN}Configured${NC}"
        else
            echo -e "  UFW Rules: ${RED}Not configured${NC}"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --list-ports | grep -q "7000/tcp"; then
            echo -e "  Firewalld Rules: ${GREEN}Configured${NC}"
        else
            echo -e "  Firewalld Rules: ${RED}Not configured${NC}"
        fi
    else
        echo -e "  Firewall: ${YELLOW}Not detected${NC}"
    fi
    
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Main function
main() {
    print_header
    check_system_requirements
    initialize_directories
    detect_os
    resolve_package_locks
    
    while true; do
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                    Main Menu                                ║${NC}"
        echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${YELLOW}║  📡 Installation & Configuration                           ║${NC}"
        echo -e "${YELLOW}║    1) Server mode (Iran server with Nginx)                ║${NC}"
        echo -e "${YELLOW}║    2) Client mode (Foreign server)                        ║${NC}"
        echo -e "${YELLOW}║    3) Quick installation (Auto-detect mode)               ║${NC}"
        echo -e "${YELLOW}║                                                           ║${NC}"
        echo -e "${YELLOW}║  🔧 Management & Monitoring                               ║${NC}"
        echo -e "${YELLOW}║    4) Show system status                                  ║${NC}"
        echo -e "${YELLOW}║    5) Show advanced status                                ║${NC}"
        echo -e "${YELLOW}║    6) Show logs (Real-time)                               ║${NC}"
        echo -e "${YELLOW}║    7) Check connections & health                          ║${NC}"
        echo -e "${YELLOW}║    8) Troubleshoot connection issues                     ║${NC}"
        echo -e "${YELLOW}║    9) Remove FRP services and cleanup                     ║${NC}"
        echo -e "${YELLOW}║    10) Show FRP installation status                      ║${NC}"
        echo -e "${YELLOW}║                                                           ║${NC}"
        echo -e "${YELLOW}║  ⚙️  Advanced Configuration                               ║${NC}"
        echo -e "${YELLOW}║    11) Edit advanced server configuration                  ║${NC}"
        echo -e "${YELLOW}║    12) Edit advanced client configuration                 ║${NC}"
        echo -e "${YELLOW}║    13) Connection optimization wizard                     ║${NC}"
        echo -e "${YELLOW}║                                                           ║${NC}"
        echo -e "${YELLOW}║  🚪 Exit                                                  ║${NC}"
        echo -e "${YELLOW}║    0) Exit                                                ║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
        
        print_footer
        
        echo -e "${CYAN}Enter your choice:${NC}"
        read -r choice
        
        case $choice in
            0)
                print_status "Exiting FRP Professional Manager..."
                exit 0
                ;;
            1)
                print_status "Installing in Server mode..."
                get_proxy_settings
                install_dependencies
                download_frp
                install_nginx
                configure_frp_server
                configure_firewall
                show_status
                ;;
            2)
                print_status "Installing in Client mode..."
                get_proxy_settings
                install_dependencies
                download_frp
                configure_frp_client
                show_status
                ;;
            3)
                quick_installation
                ;;
            4)
                show_status
                ;;
            5)
                show_advanced_status
                ;;
            6)
                show_logs
                ;;
            7)
                check_connections
                ;;
            8)
                troubleshoot_connection
                ;;
            9)
                remove_frp_services
                ;;
            10)
                show_removal_status
                ;;
            11)
                edit_advanced_server_config
                ;;
            12)
                edit_advanced_client_config
                ;;
            13)
                connection_optimization_wizard
                ;;
            *)
                print_error "Invalid choice. Please select a valid option."
                ;;
        esac
        
        echo
        echo -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
        clear
    done
}

# Run main function
main "$@"
