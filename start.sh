#!/bin/bash

# Simple start script for beginners

echo "🚀 Starting Local AI with Open WebUI..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running!"
    echo "Please start Docker Desktop first, then run this script again."
    exit 1
fi

# Check Docker context on Linux (Docker Desktop doesn't support GPU on Linux)
if [ "$(uname)" = "Linux" ]; then
    CURRENT_CONTEXT=$(docker context show 2>/dev/null || echo "default")
    if [ "$CURRENT_CONTEXT" != "default" ] && [ "$CURRENT_CONTEXT" != "" ]; then
        echo "🔍 Detected Docker context: $CURRENT_CONTEXT"
        
        # Check if GPU is available
        if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
            echo ""
            echo "⚠️  You're using Docker Desktop on Linux with an NVIDIA GPU."
            echo "   Docker Desktop doesn't support GPU acceleration on Linux."
            echo ""
            echo "Would you like to switch to native Docker for GPU support?"
            echo "1) Yes, switch to native Docker (recommended for GPU)"
            echo "2) No, continue with Docker Desktop (CPU only)"
            echo ""
            read -p "Enter your choice (1-2): " context_choice
            
            case $context_choice in
                1)
                    echo ""
                    echo "🔄 Switching to native Docker context..."
                    docker context use default
                    CURRENT_CONTEXT="default"
                    echo "✅ Switched to native Docker context"
                    
                    # Check if user is in docker group
                    if ! groups $USER | grep -q '\bdocker\b'; then
                        echo ""
                        echo "⚠️  You're not in the docker group. You may encounter permission issues."
                        echo "   To fix this, run: sudo usermod -aG docker $USER"
                        echo "   Then log out and back in (or run 'newgrp docker')"
                    fi
                    echo ""
                    ;;
                2)
                    echo ""
                    echo "ℹ️  Continuing with Docker Desktop (CPU-only mode)..."
                    echo ""
                    ;;
                *)
                    echo "Invalid choice. Continuing with current context..."
                    ;;
            esac
        else
            echo "ℹ️  Using Docker Desktop context (no GPU detected)"
        fi
    else
        # Already using native Docker, check if user has permissions
        if ! docker ps &> /dev/null; then
            if ! groups $USER | grep -q '\bdocker\b'; then
                echo ""
                echo "⚠️  Docker permission issue detected."
                echo "   You're not in the docker group. To fix this:"
                echo "   1. Run: sudo usermod -aG docker $USER"
                echo "   2. Log out and back in (or run 'newgrp docker')"
                echo "   3. Run ./start.sh again"
                echo ""
                echo "   Alternatively, you can run this script with sudo (not recommended)."
                exit 1
            fi
        fi
    fi
fi

# Check for existing containers that might conflict
echo "🔍 Checking for existing containers..."

# First, check ALL Docker contexts for containers
CONTEXTS=$(docker context ls --format "{{.Name}}" 2>/dev/null)
CURRENT_CONTEXT=$(docker context show 2>/dev/null || echo "default")
ALL_CONTAINERS_INFO=""

# Check containers in current context
EXISTING_OLLAMA=$(docker ps -aq --filter "name=ollama" 2>/dev/null)
EXISTING_WEBUI=$(docker ps -aq --filter "name=open-webui" 2>/dev/null)
PORT_11434_IN_USE=false
PORT_3000_IN_USE=false

# Check if ports are in use in current context
if docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | grep -q ":11434->"; then
    PORT_11434_IN_USE=true
fi
if docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | grep -q ":3000->"; then
    PORT_3000_IN_USE=true
fi

# Also check other contexts if on Linux
OTHER_CONTEXT_HAS_CONTAINERS=false
if [ "$(uname)" = "Linux" ] && [ -n "$CONTEXTS" ]; then
    for context in $CONTEXTS; do
        if [ "$context" != "$CURRENT_CONTEXT" ]; then
            # Temporarily switch context to check
            docker context use "$context" &>/dev/null
            OTHER_OLLAMA=$(docker ps -aq --filter "name=ollama" 2>/dev/null)
            OTHER_WEBUI=$(docker ps -aq --filter "name=open-webui" 2>/dev/null)
            
            if [ -n "$OTHER_OLLAMA" ] || [ -n "$OTHER_WEBUI" ]; then
                OTHER_CONTEXT_HAS_CONTAINERS=true
                ALL_CONTAINERS_INFO="${ALL_CONTAINERS_INFO}Context '$context' has: "
                [ -n "$OTHER_OLLAMA" ] && ALL_CONTAINERS_INFO="${ALL_CONTAINERS_INFO}ollama "
                [ -n "$OTHER_WEBUI" ] && ALL_CONTAINERS_INFO="${ALL_CONTAINERS_INFO}open-webui "
                ALL_CONTAINERS_INFO="${ALL_CONTAINERS_INFO}\n"
            fi
        fi
    done
    # Switch back to original context
    docker context use "$CURRENT_CONTEXT" &>/dev/null
fi

if [ -n "$EXISTING_OLLAMA" ] || [ -n "$EXISTING_WEBUI" ] || [ "$PORT_11434_IN_USE" = true ] || [ "$PORT_3000_IN_USE" = true ] || [ "$OTHER_CONTEXT_HAS_CONTAINERS" = true ]; then
    echo ""
    echo "⚠️  Existing containers detected that may conflict:"
    
    # Show containers in other contexts first
    if [ "$OTHER_CONTEXT_HAS_CONTAINERS" = true ]; then
        echo ""
        echo "   ⚠️  Containers found in other Docker contexts:"
        echo -e "$ALL_CONTAINERS_INFO"
        echo "   These may be using the ports even though they're not visible in current context."
    fi
    
    if [ -n "$EXISTING_OLLAMA" ]; then
        OLLAMA_STATUS=$(docker ps --filter "name=ollama" --format "{{.Status}}" 2>/dev/null)
        if [ -n "$OLLAMA_STATUS" ]; then
            echo "   • ollama container: Running ($OLLAMA_STATUS)"
        else
            echo "   • ollama container: Stopped"
        fi
    fi
    
    if [ -n "$EXISTING_WEBUI" ]; then
        WEBUI_STATUS=$(docker ps --filter "name=open-webui" --format "{{.Status}}" 2>/dev/null)
        if [ -n "$WEBUI_STATUS" ]; then
            echo "   • open-webui container: Running ($WEBUI_STATUS)"
        else
            echo "   • open-webui container: Stopped"
        fi
    fi
    
    if [ "$PORT_11434_IN_USE" = true ]; then
        CONTAINER_USING_11434=$(docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | grep ":11434->" | awk '{print $1}')
        echo "   • Port 11434 in use by: $CONTAINER_USING_11434"
    fi
    
    if [ "$PORT_3000_IN_USE" = true ]; then
        CONTAINER_USING_3000=$(docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null | grep ":3000->" | awk '{print $1}')
        echo "   • Port 3000 in use by: $CONTAINER_USING_3000"
    fi
    
    echo ""
    echo "What would you like to do?"
    echo "1) Stop and remove existing containers, then start fresh"
    echo "2) Try to restart existing containers with current configuration"
    echo "3) Exit and let me handle this manually"
    echo ""
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1)
            echo ""
            echo "🧹 Stopping and removing existing containers..."
            
            # Clean up containers in ALL contexts if needed
            if [ "$OTHER_CONTEXT_HAS_CONTAINERS" = true ] && [ -n "$CONTEXTS" ]; then
                echo "Cleaning up containers across all Docker contexts..."
                for context in $CONTEXTS; do
                    docker context use "$context" &>/dev/null
                    echo "Checking context: $context"
                    # Stop and remove ollama/open-webui in this context
                    docker stop ollama 2>/dev/null && echo "  Stopped ollama in $context" || true
                    docker rm ollama 2>/dev/null && echo "  Removed ollama in $context" || true
                    docker stop open-webui 2>/dev/null && echo "  Stopped open-webui in $context" || true
                    docker rm open-webui 2>/dev/null && echo "  Removed open-webui in $context" || true
                done
                # Switch back to original context
                docker context use "$CURRENT_CONTEXT" &>/dev/null
                echo "Switched back to context: $CURRENT_CONTEXT"
            else
                # Just clean up in current context
                if [ -n "$EXISTING_OLLAMA" ]; then
                    echo "Removing ollama container..."
                    docker stop ollama 2>/dev/null || true
                    docker rm ollama 2>/dev/null || true
                fi
                if [ -n "$EXISTING_WEBUI" ]; then
                    echo "Removing open-webui container..."
                    docker stop open-webui 2>/dev/null || true
                    docker rm open-webui 2>/dev/null || true
                fi
            fi
            
            # Also stop any other containers using the ports
            if [ "$PORT_11434_IN_USE" = true ] && [ "$CONTAINER_USING_11434" != "ollama" ]; then
                echo "Stopping container using port 11434: $CONTAINER_USING_11434"
                docker stop "$CONTAINER_USING_11434" 2>/dev/null || true
            fi
            if [ "$PORT_3000_IN_USE" = true ] && [ "$CONTAINER_USING_3000" != "open-webui" ]; then
                echo "Stopping container using port 3000: $CONTAINER_USING_3000"
                docker stop "$CONTAINER_USING_3000" 2>/dev/null || true
            fi
            echo "✅ Cleanup complete. Starting fresh setup..."
            echo ""
            ;;
        2)
            echo ""
            echo "🔄 Attempting to restart existing containers with current configuration..."
            # Stop existing containers gracefully
            if [ -n "$EXISTING_OLLAMA" ]; then
                echo "Stopping ollama container..."
                docker stop ollama 2>/dev/null || true
            fi
            if [ -n "$EXISTING_WEBUI" ]; then
                echo "Stopping open-webui container..."
                docker stop open-webui 2>/dev/null || true
            fi
            echo "✅ Existing containers stopped. Will restart with docker-compose..."
            echo ""
            ;;
        3)
            echo ""
            echo "ℹ️  Exiting. You can manually stop containers with:"
            echo "   docker stop ollama open-webui"
            echo "   docker rm ollama open-webui"
            echo "   Then run ./start.sh again"
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting..."
            exit 1
            ;;
    esac
    
    # Add a flag to indicate we handled existing containers
    HANDLED_EXISTING_CONTAINERS=true
else
    echo "✅ No conflicting containers found."
    HANDLED_EXISTING_CONTAINERS=false
fi

# Check for GPU support - but verify it actually works
GPU_AVAILABLE=false
# Only check GPU if we're using native Docker context (or not on Linux)
SKIP_GPU_CHECK=false
if [ "$(uname)" = "Linux" ]; then
    CURRENT_CONTEXT=$(docker context show 2>/dev/null || echo "default")
    if [ "$CURRENT_CONTEXT" != "default" ] && [ "$CURRENT_CONTEXT" != "" ]; then
        echo "⚠️  Skipping GPU check (Docker Desktop doesn't support GPU on Linux)"
        SKIP_GPU_CHECK=true
    fi
fi

if [ "$SKIP_GPU_CHECK" = false ] && command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        echo "🔍 NVIDIA GPU detected, checking Docker GPU support..."
        
        # Auto-detect CUDA version and container image
        CUDA_VERSION=$(nvidia-smi 2>/dev/null | grep "CUDA Version" | sed 's/.*CUDA Version: \([0-9.]*\).*/\1/' | head -1)
        if [ -n "$CUDA_VERSION" ]; then
            # Extract major.minor version and use well-known CUDA image tags
            CUDA_MAJOR_MINOR=$(echo "$CUDA_VERSION" | cut -d. -f1,2)
            case "$CUDA_MAJOR_MINOR" in
                "11.4") CUDA_TEST_IMAGE="nvidia/cuda:11.4.3-base-ubuntu20.04" ;;
                "11.8") CUDA_TEST_IMAGE="nvidia/cuda:11.8.0-base-ubuntu20.04" ;;
                "12.0") CUDA_TEST_IMAGE="nvidia/cuda:12.0.1-base-ubuntu20.04" ;;
                "12.1") CUDA_TEST_IMAGE="nvidia/cuda:12.1.1-base-ubuntu20.04" ;;
                "12.2") CUDA_TEST_IMAGE="nvidia/cuda:12.2.2-base-ubuntu20.04" ;;
                *) CUDA_TEST_IMAGE="nvidia/cuda:11.4.3-base-ubuntu20.04" ;;  # Fallback
            esac
        else
            CUDA_TEST_IMAGE="nvidia/cuda:11.4.3-base-ubuntu20.04"  # Fallback
        fi
        
        # Also check if Docker can actually use the GPU
        if docker run --rm --gpus all "$CUDA_TEST_IMAGE" nvidia-smi &> /dev/null 2>&1; then
            GPU_AVAILABLE=true
            echo "✅ GPU is ready! Using GPU-accelerated setup..."
        else
            echo ""
            echo "⚠️  NVIDIA GPU detected but Docker can't access it!"
            echo "   This is usually because NVIDIA Container Toolkit is not installed."
            echo ""
            echo "   🔧 To fix this, run: ./fix-gpu.sh"
            echo ""
            echo "   For now, using CPU-only setup (models will run slower)."
            echo "   After fixing, run ./start.sh again for GPU acceleration."
            echo ""
        fi
    fi
fi

# Add force-recreate flag if we handled existing containers
COMPOSE_FLAGS="-d"
if [ "$HANDLED_EXISTING_CONTAINERS" = true ]; then
    COMPOSE_FLAGS="$COMPOSE_FLAGS --force-recreate"
    echo "🔄 Starting services with fresh containers..."
else
    echo "🚀 Starting services..."
fi

if [ "$GPU_AVAILABLE" = true ]; then
    docker-compose -f docker-compose.gpu.yml up $COMPOSE_FLAGS
else
    echo "📝 Using CPU-only setup..."
    echo "   (This is fine, but models will run slower)"
    docker-compose up $COMPOSE_FLAGS
fi

echo ""
echo "⏳ Waiting for services to start..."
sleep 5

# Check if services are running and healthy
if docker-compose ps | grep -q "Up"; then
    echo ""
    echo "✅ Containers started successfully!"
    echo ""
    
    # Check health status of containers
    echo "🔍 Checking container health..."
    
    # Wait a bit more for health checks to complete
    sleep 10
    
    # Check ollama health
    OLLAMA_STATUS=$(docker ps --filter "name=ollama" --format "{{.Status}}" 2>/dev/null)
    if echo "$OLLAMA_STATUS" | grep -q "Up.*healthy\|Up.*starting"; then
        echo "✅ Ollama: Healthy"
        OLLAMA_HEALTHY=true
    elif echo "$OLLAMA_STATUS" | grep -q "Up"; then
        echo "⚠️  Ollama: Running but no health status"
        OLLAMA_HEALTHY=true
    else
        echo "❌ Ollama: Not running properly"
        OLLAMA_HEALTHY=false
    fi
    
    # Check open-webui health
    WEBUI_STATUS=$(docker ps --filter "name=open-webui" --format "{{.Status}}" 2>/dev/null)
    if echo "$WEBUI_STATUS" | grep -q "Up.*healthy"; then
        echo "✅ Open WebUI: Healthy"
        WEBUI_HEALTHY=true
    elif echo "$WEBUI_STATUS" | grep -q "Up.*unhealthy"; then
        echo "⚠️  Open WebUI: Running but unhealthy (checking logs...)"
        echo ""
        echo "🔍 Recent Open WebUI logs:"
        docker logs open-webui --tail 10 2>/dev/null || echo "Could not retrieve logs"
        echo ""
        echo "🔧 This is often a temporary startup issue. The service may still work."
        echo "   Try accessing http://localhost:3000 in a few minutes."
        WEBUI_HEALTHY=false
    elif echo "$WEBUI_STATUS" | grep -q "Up.*starting"; then
        echo "⏳ Open WebUI: Still starting up..."
        WEBUI_HEALTHY=true
    elif echo "$WEBUI_STATUS" | grep -q "Up"; then
        echo "⚠️  Open WebUI: Running but no health status"
        WEBUI_HEALTHY=true
    else
        echo "❌ Open WebUI: Not running properly"
        WEBUI_HEALTHY=false
    fi
    
    echo ""
    
    if [ "$OLLAMA_HEALTHY" = true ] && [ "$WEBUI_HEALTHY" = true ]; then
        echo "🎉 All services are healthy and ready!"
    elif [ "$OLLAMA_HEALTHY" = true ]; then
        echo "⚠️  Ollama is healthy but Open WebUI may have issues."
        echo "   You can still try accessing the interface."
    else
        echo "⚠️  Some services may have issues. Check the logs above."
    fi
    
    echo ""
    echo "📌 Next steps:"
    echo "   1. Open your browser and go to: http://localhost:3000"
    echo "   2. Create an account (first user becomes admin)"
    echo "   3. Download a model: type /models in chat, click + and add 'llama3.2:3b'"
    echo "   4. Start chatting!"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   • If page doesn't load, wait 2-3 minutes and try again"
    echo "   • Check logs with: docker-compose logs -f"
    echo "   • Check container status with: docker ps"
else
    echo ""
    echo "❌ Something went wrong. Running diagnostics..."
    docker-compose ps
    echo ""
    echo "Container logs:"
    echo "==============="
    docker-compose logs --tail 20
    echo ""
    echo "Try running: docker-compose logs -f"
fi