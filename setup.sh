#!/bin/bash

# System Updates and Basic Installations
# 
# Update and Upgrade the System
# This script is intended to be run on a clean Ubuntu 24.04 server.
# It is recommended to run this script with root privileges.
# dont forget to run chmod +x setup.sh
# and then run ./setup.sh



sudo apt-get update
sudo apt-get upgrade -y

# Install NVIDIA and Development Tools
sudo apt-get install -y nvidia-cuda-toolkit
sudo apt-get install -y screen curl iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev \
    tar clang bsdmainutils ncdu unzip

# Install Python and Node.js
sudo apt-get install -y python3 python3-pip python3-venv python3-dev
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Yarn
sudo npm install -g yarn
curl -o- -L https://yarnpkg.com/install.sh | bash
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
source ~/.bashrc


# Version Checks
echo "Checking NVIDIA Driver:"
nvidia-smi

echo "Checking CUDA Version:"
nvcc --version

echo "Checking Node.js Version:"
node -v

echo "Checking Yarn Version:"
yarn -v


# Setup Python Virtual Environment
# python3 -m venv .venv
# source .venv/bin/activate
# Run the main script
# ./run_rl_swarm.sh
# Deactivate the virtual environment
# deactivate
# Install Python Packages


