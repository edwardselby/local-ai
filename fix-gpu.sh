#!/bin/bash

echo "🔧 GPU Diagnostic and Fix Script"
echo "================================="
echo ""

# Auto-detect system information
echo "🔍 Detecting system configuration..."

# Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/engine/install/"
    exit 1
fi

# Detect package manager
if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt-get"
    PKG_UPDATE="apt-get update"
    PKG_INSTALL="apt-get install -y"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    PKG_UPDATE="dnf check-update"
    PKG_INSTALL="dnf install -y"
elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
    PKG_UPDATE="yum check-update"
    PKG_INSTALL="yum install -y"
else
    echo "⚠️  Unsupported package manager. This script supports apt-get, dnf, and yum."
    PKG_MANAGER="apt-get"
    PKG_UPDATE="apt-get update"
    PKG_INSTALL="apt-get install -y"
fi

# Detect init system
if command -v systemctl >/dev/null 2>&1; then
    INIT_SYSTEM="systemd"
    RESTART_DOCKER="sudo systemctl restart docker"
    RELOAD_DAEMON="sudo systemctl daemon-reload"
else
    INIT_SYSTEM="sysv"
    RESTART_DOCKER="sudo service docker restart"
    RELOAD_DAEMON=""
fi

# Auto-detect GPU and driver information
if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1)
    DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null | head -1)
    CUDA_VERSION=$(nvidia-smi 2>/dev/null | grep "CUDA Version" | sed 's/.*CUDA Version: \([0-9.]*\).*/\1/' | head -1)
    
    if [ -z "$GPU_NAME" ] || [ -z "$DRIVER_VERSION" ]; then
        echo "❌ Failed to detect NVIDIA GPU information. Make sure NVIDIA drivers are installed."
        exit 1
    fi
else
    echo "❌ nvidia-smi not found. Please install NVIDIA drivers first."
    exit 1
fi

# Detect OS version for container selection
if command -v lsb_release >/dev/null 2>&1; then
    OS_VERSION_FULL=$(lsb_release -rs 2>/dev/null)
    OS_NAME=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]')
else
    # Fallback to /etc/os-release
    OS_NAME=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
    OS_VERSION_FULL=$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
fi

# Convert OS version to container format (e.g., "22.04" -> "ubuntu20.04")
if [ -n "$OS_VERSION_FULL" ] && [ "$OS_NAME" = "ubuntu" ]; then
    case "$OS_VERSION_FULL" in
        "22.04") CONTAINER_OS="ubuntu20.04" ;;  # Use 20.04 for compatibility
        "20.04") CONTAINER_OS="ubuntu20.04" ;;
        "18.04") CONTAINER_OS="ubuntu18.04" ;;
        *) CONTAINER_OS="ubuntu20.04" ;;  # Default fallback
    esac
else
    # For non-Ubuntu systems, use a compatible Ubuntu version
    CONTAINER_OS="ubuntu20.04"
fi

# Construct CUDA container image name with proper versioning
if [ -n "$CUDA_VERSION" ]; then
    # Extract major.minor version (e.g., "11.4" from "11.4.3")
    CUDA_MAJOR_MINOR=$(echo "$CUDA_VERSION" | cut -d. -f1,2)
    # Use well-known CUDA image tags
    case "$CUDA_MAJOR_MINOR" in
        "11.4") CUDA_IMAGE="nvidia/cuda:11.4.3-base-ubuntu20.04" ;;
        "11.8") CUDA_IMAGE="nvidia/cuda:11.8.0-base-ubuntu20.04" ;;
        "12.0") CUDA_IMAGE="nvidia/cuda:12.0.1-base-ubuntu20.04" ;;
        "12.1") CUDA_IMAGE="nvidia/cuda:12.1.1-base-ubuntu20.04" ;;
        "12.2") CUDA_IMAGE="nvidia/cuda:12.2.2-base-ubuntu20.04" ;;
        *) CUDA_IMAGE="nvidia/cuda:11.4.3-base-ubuntu20.04" ;;  # Fallback
    esac
else
    CUDA_IMAGE="nvidia/cuda:11.4.3-base-ubuntu20.04"  # Fallback
fi

echo "✅ Package Manager: $PKG_MANAGER"
echo "✅ Init System: $INIT_SYSTEM"
echo "✅ Container Image: $CUDA_IMAGE"

# Check current status
echo ""
echo "📊 Current GPU Status:"
echo "----------------------"
echo "✅ GPU Hardware: $GPU_NAME detected"
echo "✅ NVIDIA Driver: Version $DRIVER_VERSION installed"
if [ -n "$CUDA_VERSION" ]; then
    echo "✅ CUDA Version: $CUDA_VERSION"
fi
echo "❌ Docker GPU Support: Not working - NVIDIA Container Toolkit missing"
echo ""

echo "The issue is that the NVIDIA Container Toolkit is not installed."
echo "This toolkit allows Docker to access your GPU."
echo ""

echo "📦 To fix this, run these commands:"
echo "------------------------------------"
echo ""
echo "# 1. Add NVIDIA Container Toolkit repository"
echo "distribution=\$(. /etc/os-release;echo \$ID\$VERSION_ID)"
echo "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
if [ "$PKG_MANAGER" = "apt-get" ]; then
    echo "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \\"
    echo "  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \\"
    echo "  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"
else
    echo "# For RPM-based systems, add the repository:"
    echo "curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \\"
    echo "  sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo"
fi
echo ""
echo "# 2. Update package list and install"
echo "sudo $PKG_UPDATE"
echo "sudo $PKG_INSTALL nvidia-container-toolkit"
echo ""
echo "# 3. Configure Docker to use NVIDIA runtime"
echo "sudo nvidia-ctk runtime configure --runtime=docker"
echo ""
echo "# 4. Restart Docker"
if [ -n "$RELOAD_DAEMON" ]; then
    echo "$RELOAD_DAEMON"
fi
echo "$RESTART_DOCKER"
echo ""
echo "# 5. Test GPU access"
echo "docker run --rm --gpus all $CUDA_IMAGE nvidia-smi"
echo ""
echo "----------------------------------------"
echo ""
echo "Would you like to run these commands automatically? (y/n)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Installing NVIDIA Container Toolkit..."
    
    # Add repository
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
          sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
          sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    else
        # For RPM-based systems
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
          sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
    fi
    
    # Install using detected package manager
    echo "Updating package lists..."
    if [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        sudo $PKG_UPDATE || true  # Don't fail if check-update returns non-zero
    else
        sudo $PKG_UPDATE
    fi
    
    echo "Installing NVIDIA Container Toolkit..."
    sudo $PKG_INSTALL nvidia-container-toolkit
    
    # Configure Docker
    sudo nvidia-ctk runtime configure --runtime=docker
    
    # Restart Docker using detected method
    echo "Restarting Docker..."
    if [ -n "$RELOAD_DAEMON" ]; then
        $RELOAD_DAEMON
    fi
    $RESTART_DOCKER
    
    echo ""
    echo "✅ Installation complete! Testing GPU access..."
    sleep 3
    
    # Fix missing library links for driver 470
    echo ""
    echo "🔗 Creating symbolic links for NVIDIA libraries (driver fix)..."
    
    # Find and link all necessary NVIDIA libraries
    DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)
    ARCH=$(dpkg --print-architecture)
    if [ "$ARCH" = "amd64" ]; then
        LIB_DIR="/usr/lib/x86_64-linux-gnu"
    elif [ "$ARCH" = "i386" ]; then
        LIB_DIR="/usr/lib/i386-linux-gnu"
    else
        # Fallback: try to find the library directory automatically
        LIB_DIR=$(find /usr/lib -name "libnvidia-ml.so.${DRIVER_VER}" -type f 2>/dev/null | head -1 | xargs dirname)
        if [ -z "$LIB_DIR" ]; then
            echo "⚠️  Could not find NVIDIA library directory for architecture $ARCH"
            LIB_DIR="/usr/lib/x86_64-linux-gnu"  # Default fallback
        fi
    fi
    
    echo "Detected NVIDIA driver version: $DRIVER_VER"
    echo "Using library directory: $LIB_DIR"
    
    # Create links for all required NVIDIA libraries
    for lib in libnvidia-ml.so libnvidia-cfg.so.1 libnvidia-nvvm.so.4; do
        if [ -f "${LIB_DIR}/${lib}.${DRIVER_VER}" ]; then
            BASE_NAME=$(echo "$lib" | sed 's/\.so.*/.so/')
            TARGET_SUFFIX=$(echo "$lib" | grep -o '\.so.*')
            sudo ln -sf "${LIB_DIR}/${lib}.${DRIVER_VER}" "${LIB_DIR}/${BASE_NAME}${TARGET_SUFFIX}"
            echo "Created link: ${BASE_NAME}${TARGET_SUFFIX} -> ${lib}.${DRIVER_VER}"
        fi
    done
    
    # Special case for libnvidia-ml.so.1 (most important one)
    if [ -f "${LIB_DIR}/libnvidia-ml.so.${DRIVER_VER}" ]; then
        sudo ln -sf "${LIB_DIR}/libnvidia-ml.so.${DRIVER_VER}" "${LIB_DIR}/libnvidia-ml.so.1"
        echo "Created link: libnvidia-ml.so.1 -> libnvidia-ml.so.${DRIVER_VER}"
    fi
    
    # Update library cache
    sudo ldconfig
    
    # Configure Docker daemon for legacy NVIDIA support
    echo ""
    echo "⚙️ Configuring Docker for NVIDIA driver $DRIVER_VERSION compatibility..."
    
    # Create/update Docker daemon config with legacy support
    if [ -f /etc/docker/daemon.json ]; then
        # Backup existing config
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
    fi
    
    # Create new daemon.json with NVIDIA runtime configuration
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
    
    echo "Docker daemon configured for NVIDIA runtime"
    
    # Restart Docker with new configuration
    echo "Restarting Docker with new configuration..."
    if [ -n "$RELOAD_DAEMON" ]; then
        $RELOAD_DAEMON
    fi
    $RESTART_DOCKER
    sleep 3
    
    # Check if using Docker Desktop and switch to native Docker if needed
    echo ""
    echo "🔄 Checking Docker context..."
    CURRENT_CONTEXT=$(docker context show 2>/dev/null || echo "default")
    if [ "$CURRENT_CONTEXT" != "default" ]; then
        echo "Switching from Docker Desktop to native Docker for GPU support..."
        docker context use default
        echo "✅ Switched to native Docker context"
    else
        echo "✅ Already using native Docker context"
    fi
    
    # Add user to docker group if not already a member
    echo ""
    echo "👤 Checking Docker group membership..."
    if ! groups $USER | grep -q '\bdocker\b'; then
        echo "Adding user $USER to docker group..."
        sudo usermod -aG docker $USER
        echo "✅ User added to docker group"
        echo ""
        echo "⚠️  Note: You'll need to log out and back in (or run 'newgrp docker') for group changes to take effect."
        echo "After logging back in, test with: docker run --rm --gpus all $CUDA_IMAGE nvidia-smi"
    else
        echo "✅ User already in docker group"
    fi
    
    # Test with environment variable to bypass some checks
    echo ""
    echo "Testing GPU access..."
    if NVIDIA_DISABLE_REQUIRE=1 docker run --rm --gpus all -e NVIDIA_DISABLE_REQUIRE=1 $CUDA_IMAGE nvidia-smi; then
        echo ""
        echo "🎉 Success! GPU is now accessible to Docker!"
        echo ""
        echo "You can now run: ./start.sh"
        echo "The script will automatically use GPU acceleration."
    else
        echo ""
        echo "⚠️  GPU test failed. Please try:"
        echo ""
        echo "1. Reboot your system:"
        echo "   sudo reboot"
        echo ""
        echo "2. After reboot, test with:"
        echo "   docker run --rm --gpus all $CUDA_IMAGE nvidia-smi"
        echo ""
        echo "3. If still not working, you may need to reinstall NVIDIA drivers:"
        if [ "$PKG_MANAGER" = "apt-get" ]; then
            echo "   sudo $PKG_INSTALL --reinstall nvidia-driver-$DRIVER_VERSION"
        else
            echo "   sudo $PKG_INSTALL nvidia-driver-$DRIVER_VERSION"
        fi
    fi
else
    echo ""
    echo "ℹ️  You can run the commands manually as shown above."
    echo "After installation, run ./start.sh to use GPU acceleration."
fi