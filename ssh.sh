#!/bin/bash
# Configure SSH and Tailscale on a new Linux GPU machine

# Exit on any error
set -e

echo "=== Linux SSH and Tailscale Setup Script ==="
echo "This script will configure SSH and Tailscale for remote access."

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install SSH server
echo "Installing SSH server..."
sudo apt install -y openssh-server

# Enable and start SSH
echo "Enabling SSH service..."
sudo systemctl enable ssh
sudo systemctl start ssh

# Install Tailscale
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sudo sh

# Configure Tailscale to start at boot
sudo systemctl enable tailscaled

# Start Tailscale and authenticate
echo "Starting Tailscale. You'll need to authenticate in a browser..."
sudo tailscale up

# Show Tailscale status
echo "Tailscale status:"
tailscale status

# Check for NVIDIA GPU
echo "Checking for NVIDIA GPU..."
if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA GPU detected:"
    nvidia-smi
else
    echo "No NVIDIA GPU detected or drivers not installed."
    echo "If your machine has an NVIDIA GPU, install drivers with:"
    echo "sudo apt install nvidia-driver-XXX"
fi

# Get IP information
echo "Your Tailscale IP is:"
tailscale ip

echo "=== Setup Complete ==="
echo "To connect from your Mac, use: ssh $(whoami)@$(tailscale ip)"
echo "Remember to copy your SSH key with: ssh-copy-id $(whoami)@$(tailscale ip)"
