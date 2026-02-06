echo "Checking Internet Pi status..."
# Check if services are running
if command -v docker &> /dev/null; then
    echo -e "\nDocker containers status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  else
    echo "Docker not installed"
fi
