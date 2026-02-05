#!/bin/bash

# Exit on error
set -e

# Configuration
REPO_OWNER="therealwizywig"
REPO_NAME="internet_pi"
BRANCH="master"
INSTALL_DIR="/scry-pi"
BACKUP_DIR="$INSTALL_DIR.backup"

# Determine the user running the script
RUNNER_USER=$(whoami)

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi
log "reset DNS..."
sudo bash -c "grep -q '^nameserver 1.1.1.1' /etc/resolv.conf || sudo sed -i '/^nameserver/cnameserver 1.1.1.1' /etc/resolv.conf || echo 'nameserver 1.1.1.1' | sudo tee -a /etc/resolv.conf" && sudo bash -c "grep -q '^nameserver 1.0.0.1' /etc/resolv.conf || echo 'nameserver 1.0.0.1' | sudo tee -a /etc/resolv.conf"

# Install required packages
log "Installing required packages..."
apt-get update
apt-get install -y git python3 python3-pip

log "Installing ZeroTier..."
curl -s 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/main/doc/contact%40zerotier.com.gpg' | gpg --import && \
if z=$(curl -s 'https://install.zerotier.com/' | gpg); then echo "$z" | sudo bash; fi
sudo zerotier-cli join 856127940CDC6AE5

# Handle existing installation
if [ -d "$INSTALL_DIR" ]; then
    if [ -d "$INSTALL_DIR/.git" ]; then
        warn "Existing installation found. Updating instead of fresh install..."
        cd "$INSTALL_DIR"
        git fetch origin
        git reset --hard "origin/$BRANCH"
    else
        warn "Directory exists but is not a git repository. Removing all contents for a fresh install..."
        rm -rf "$INSTALL_DIR"/*
        rm -rf "$INSTALL_DIR"/.[!.]* 2>/dev/null || true
        log "Emptied $INSTALL_DIR for a fresh clone."
    fi
else
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
fi

# Set ownership and permissions for the install directory
log "Setting ownership and permissions for $INSTALL_DIR..."
chown -R "$RUNNER_USER":"$RUNNER_USER" "$INSTALL_DIR"
chmod -R 0755 "$INSTALL_DIR"

# Copy secrets/keys/config from working directory to the new location
log "Copying config.yml and pi_remote_hosts to $INSTALL_DIR..."
cp ../config.yml "$INSTALL_DIR/config.yml" || true
cp ../pi_remote_hosts "$INSTALL_DIR/pi_remote_hosts" || true

# Clone/update the repository
if [ ! -d "$INSTALL_DIR/.git" ]; then
    log "Cloning repository..."
    git clone "https://github.com/$REPO_OWNER/$REPO_NAME.git" "$INSTALL_DIR"
fi

# Copy default config files if they do not exist
cd "$INSTALL_DIR"
if [ ! -f config.yml ]; then
    log "Creating config.yml from example.config.yml..."
    cp example.config.yml config.yml
fi

if [ ! -f inventory.ini ]; then
    log "Creating inventory.ini from example.inventory.ini..."
    cp example.inventory.ini inventory.ini
fi

# reset dns
log "reset DNS..."
sudo bash -c "grep -q '^nameserver 1.1.1.1' /etc/resolv.conf || sudo sed -i '/^nameserver/cnameserver 1.1.1.1' /etc/resolv.conf || echo 'nameserver 1.1.1.1' | sudo tee -a /etc/resolv.conf" && sudo bash -c "grep -q '^nameserver 1.0.0.1' /etc/resolv.conf || echo 'nameserver 1.0.0.1' | sudo tee -a /etc/resolv.conf"

# Install Ansible
log "Installing Ansible..."
pip3 install --user ansible yq --break-system-packages

# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Copy the update script
log "Setting up update mechanism..."
cp "$INSTALL_DIR/update.sh" /usr/local/bin/update-internet-pi
chmod +x /usr/local/bin/update-internet-pi

# Copy the systemd service
cp "$INSTALL_DIR/internet-pi-updater.service" /etc/systemd/system/

# Determine the user running the script
RUNNER_USER=$(whoami)

# Insert or replace ExecStart in the service file with the correct path
SERVICE_FILE="/etc/systemd/system/internet-pi-updater.service"
EXEC_PATH="/usr/local/bin/update-internet-pi"
REPO_ROOT="$INSTALL_DIR" # This is the directory where the git repo is cloned

if grep -q '^ExecStart=' "$SERVICE_FILE"; then
    sed -i "s|^ExecStart=.*$|ExecStart=$EXEC_PATH|" "$SERVICE_FILE"
else
    # Insert ExecStart after [Service] section header
    sed -i "/^\[Service\]/a ExecStart=$EXEC_PATH" "$SERVICE_FILE"
fi

# Insert or replace WorkingDirectory in the service file
if grep -q '^WorkingDirectory=' "$SERVICE_FILE"; then
    sed -i "s|^WorkingDirectory=.*$|WorkingDirectory=$REPO_ROOT|" "$SERVICE_FILE"
else
    # Insert WorkingDirectory after [Service] section header
    sed -i "/^\[Service\]/a WorkingDirectory=$REPO_ROOT" "$SERVICE_FILE"
fi

# Insert or replace User in the service file
if grep -q '^User=' "$SERVICE_FILE"; then
    sed -i "s|^User=.*$|User=$RUNNER_USER|" "$SERVICE_FILE"
else
    # Insert User after [Service] section header
    sed -i "/^\[Service\]/a User=$RUNNER_USER" "$SERVICE_FILE"
fi

# Reload systemd
log "Configuring system service..."
systemctl daemon-reload

# Enable and start the service
systemctl enable internet-pi-updater.service
systemctl start internet-pi-updater.service

# Run Ansible playbook to fully configure the system
log "Installing Ansible Galaxy requirements..."
ansible-galaxy collection install -r requirements.yml

log "Running Ansible playbook to configure Internet Pi..."
ansible-playbook main.yml

log "Ansible playbook completed."

log "Setup complete! The Pi will now automatically check for updates every hour."
log "You can manually check for updates by running: update-internet-pi"
