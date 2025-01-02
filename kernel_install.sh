#!/bin/bash

# Function to check if running with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run with sudo"
        exit 1
    fi
}

# Function to install dependencies
install_dependencies() {
    echo "Installing required dependencies..."
    apt-get update
    apt-get install -y \
        git \
        fakeroot \
        build-essential \
        ncurses-dev \
        xz-utils \
        libssl-dev \
        bc \
        flex \
        libelf-dev \
        bison \
        curl \
        wget
}

# Function to fetch available kernel versions
fetch_kernel_versions() {
    echo "Fetching available kernel versions..."
    KERNEL_PAGE=$(curl -s https://www.kernel.org/)
    
    # Extract latest stable version
    LATEST_STABLE=$(echo "$KERNEL_PAGE" | grep -A 1 "latest_link" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    
    # Extract all stable versions
    STABLE_VERSIONS=$(echo "$KERNEL_PAGE" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | sort -V -r)
    
    echo "Latest stable version: $LATEST_STABLE"
    echo -e "\nAvailable stable versions:"
    echo "$STABLE_VERSIONS"
}

# Function to download and install kernel
install_kernel() {
    local version=$1
    local work_dir="$HOME/kernel_source"
    
    echo "Starting installation of Linux kernel $version"
    
    # Create working directory
    mkdir -p "$work_dir"
    cd "$work_dir"
    
    # Download kernel
    echo "Downloading kernel source..."
    wget "https://cdn.kernel.org/pub/linux/kernel/v${version:0:1}.x/linux-$version.tar.xz"
    
    if [ $? -ne 0 ]; then
        echo "Failed to download kernel"
        return 1
    fi
    
    # Extract kernel
    echo "Extracting kernel source..."
    tar xf "linux-$version.tar.xz"
    cd "linux-$version"
    
    # Copy current config as base
    echo "Copying current kernel config..."
    cp /boot/config-$(uname -r) .config
    
    # Optionally run menuconfig
    read -p "Do you want to customize kernel configuration? (y/n) " answer
    if [ "$answer" = "y" ]; then
        make menuconfig
    fi
    
    # Build kernel
    echo "Building kernel (this will take some time)..."
    make -j$(nproc)
    
    if [ $? -ne 0 ]; then
        echo "Kernel build failed"
        return 1
    fi
    
    # Install modules and kernel
    echo "Installing kernel modules..."
    sudo make modules_install
    echo "Installing kernel..."
    sudo make install
    
    # Update bootloader
    echo "Updating bootloader..."
    sudo update-grub
    
    echo "Kernel $version installation completed!"
    echo "Please reboot your system to use the new kernel"
}

# Function to check current kernel version
check_current_kernel() {
    echo "Current kernel version: $(uname -r)"
}

# Main menu
main_menu() {
    while true; do
        echo -e "\n=== Linux Kernel Installation Script ==="
        echo "1. Check current kernel version"
        echo "2. Show available kernel versions"
        echo "3. Install specific kernel version"
        echo "4. Install latest stable kernel"
        echo "5. Install dependencies"
        echo "6. Exit"
        
        read -p "Select an option (1-6): " choice
        
        case $choice in
            1)
                check_current_kernel
                ;;
            2)
                fetch_kernel_versions
                ;;
            3)
                read -p "Enter kernel version to install (e.g., 6.12.7): " version
                install_kernel "$version"
                ;;
            4)
                LATEST_VERSION=$(curl -s https://www.kernel.org/ | grep -A 1 "latest_link" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
                install_kernel "$LATEST_VERSION"
                ;;
            5)
                install_dependencies
                ;;
            6)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

# Start script
echo "Linux Kernel Installation Script"
check_sudo
main_menu
