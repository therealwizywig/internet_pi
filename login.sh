#!/bin/bash

# Exit on error
set -e

CONFIG_DIR="/scry-pi"
CONFIG_FILE="$CONFIG_DIR/config.yml"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}
warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}
error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

if [ ! -f "$CONFIG_DIR" ]; then
    # Ensure the config directory exists
    mkdir -p "$CONFIG_DIR"
    cp example.config.yml "$CONFIG_DIR/"
fi
    if [ -f "$CONFIG_DIR/example.config.yml" ]; then
        cp "$CONFIG_DIR/example.config.yml" "$CONFIG_FILE"
        log "Created $CONFIG_FILE from example.config.yml."
    else
        error "config.yml not found at $CONFIG_FILE and example.config.yml not found in $CONFIG_DIR. Please ensure one exists."
        exit 1
    fi

# Read current values
declare -A config
log "Reading current configuration..."
config[location]=$(grep '^custom_metrics_location:' "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
config[collection_interval]=$(grep '^custom_metrics_collection_interval:' "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
config[custom_metrics_location]=$(grep '^custom_metrics_location:' "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
config[tables]=$(grep '^custom_metrics_tables:' "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Debug output
log "Current configuration values:"
echo "Location: '${config[location]}'"
echo "Collection Interval: '${config[collection_interval]}'"
echo "Tables: '${config[tables]}'"

config[pghost]=$(grep '^custom_metrics_pghost:' "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
config[pgdatabase]=$(grep '^custom_metrics_pgdatabase:' "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
config[pguser]=$(grep '^custom_metrics_pguser:' "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
config[pgpassword]=$(grep '^custom_metrics_pgpassword:' "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

echo "PGHOST: '${config[pghost]}'"
echo "PGDATABASE: '${config[pgdatabase]}'"
echo "PGUSER: '${config[pguser]}'"
echo "PGPASSWORD: '${config[pgpassword]}'"
echo

# Prompt for each value
echo

echo "Current Location: ${config[location]}"
read -p "Enter Location (e.g., home, office, remote) [${config[location]}]: " input
if [ -n "$input" ]; then config[location]="$input"; fi

echo "Current Collection Interval: ${config[collection_interval]}"
read -p "Enter Collection Interval (e.g., 5m, 1h) [${config[collection_interval]}]: " input
if [ -n "$input" ]; then config[collection_interval]="$input"; fi

echo
echo "PostgreSQL Configuration (leave blank to keep current value)"
echo "----------------------------------------------------------"
echo "Current PGHOST: ${config[pghost]}"
read -p "Enter PGHOST [${config[pghost]}]: " input
if [ -n "$input" ]; then config[pghost]="$input"; fi

echo "Current PGDATABASE: ${config[pgdatabase]}"
read -p "Enter PGDATABASE [${config[pgdatabase]}]: " input
if [ -n "$input" ]; then config[pgdatabase]="$input"; fi

echo "Current PGUSER: ${config[pguser]}"
read -p "Enter PGUSER [${config[pguser]}]: " input
if [ -n "$input" ]; then config[pguser]="$input"; fi

echo "Current PGPASSWORD: ${config[pgpassword]}"
read -p "Enter PGPASSWORD [${config[pgpassword]}]: " input
if [ -n "$input" ]; then config[pgpassword]="$input"; fi

echo
echo "Summary of PostgreSQL configuration to be saved:"
echo "  Location: ${config[location]}"
echo "  Collection Interval: ${config[collection_interval]}"
echo "  Tables: ${config[tables]}"
echo "  PGHOST: ${config[pghost]}"
echo "  PGDATABASE: ${config[pgdatabase]}"
echo "  PGUSER: ${config[pguser]}"
echo "  PGPASSWORD: ${config[pgpassword]}"
read -p "Is this correct? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn] ]]; then
    echo "Aborting. No changes made."
    exit 1
fi

# Update config.yml with proper file path - Linux compatible sed
sed -i "s|^custom_metrics_location:.*|custom_metrics_location: \"${config[location]}\"|" "$CONFIG_FILE"
sed -i "s|^custom_metrics_collection_interval:.*|custom_metrics_collection_interval: \"${config[collection_interval]}\"|" "$CONFIG_FILE"

sed -i "s|^custom_metrics_pghost:.*|custom_metrics_pghost: \"${config[pghost]}\"|" "$CONFIG_FILE"
sed -i "s|^custom_metrics_pgdatabase:.*|custom_metrics_pgdatabase: \"${config[pgdatabase]}\"|" "$CONFIG_FILE"
sed -i "s|^custom_metrics_pguser:.*|custom_metrics_pguser: \"${config[pguser]}\"|" "$CONFIG_FILE"
sed -i "s|^custom_metrics_pgpassword:.*|custom_metrics_pgpassword: \"${config[pgpassword]}\"|" "$CONFIG_FILE"

log "PostgreSQL configuration updated in $CONFIG_FILE."
