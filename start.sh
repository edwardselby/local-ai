#!/bin/bash

# Local AI Start Script - Refactored for clarity and DRY principles
set -e  # Exit on error

# ============================================================================
# Configuration
# ============================================================================
readonly SCRIPT_NAME="Local AI with Open WebUI"
readonly OLLAMA_PORT=11434
readonly WEBUI_PORT=3000
readonly TTS_PORT=8001
readonly DEFAULT_CUDA_IMAGE="nvidia/cuda:11.4.3-base-ubuntu20.04"

# Service configurations
declare -A SERVICES=(
    [ollama]="Ollama LLM Backend"
    [open-webui]="Open WebUI Interface"
    [tts-service]="Text-to-Speech Service"
)

# Parse command line arguments
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n    Run in dry-run mode (no actual Docker operations)"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Dry-run mode will:"
            echo "  - Show all prompts and collect user choices"
            echo "  - Display what would be executed"
            echo "  - Skip actual Docker operations"
            exit 0
            ;;
    esac
done

# ============================================================================
# Helper Functions
# ============================================================================

# Print formatted messages
print_header() {
    if [ "$DRY_RUN" = true ]; then
        echo "🚀 Starting $SCRIPT_NAME... [DRY-RUN MODE]"
        echo "📝 No actual Docker operations will be performed"
    else
        echo "🚀 Starting $SCRIPT_NAME..."
    fi
    echo ""
}

print_section() {
    echo ""
    echo "$1"
    echo "${1//?/-}"
}

print_error() {
    echo "❌ $1" >&2
}

print_warning() {
    echo "⚠️  $1" >&2
}

print_success() {
    echo "✅ $1"
}

print_info() {
    echo "ℹ️  $1" >&2
}

# ============================================================================
# Docker Functions
# ============================================================================

# Check if Docker daemon is running and accessible
check_docker_daemon() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would check Docker daemon status"
        return 0
    fi

    if docker info > /dev/null 2>&1; then
        return 0
    fi

    # Docker is not accessible
    if [ "$(uname)" != "Linux" ]; then
        print_error "Docker is not running!"
        echo "Please start Docker Desktop first, then run this script again."
        return 1
    fi

    # On Linux, check if it's a permission issue or daemon not running
    if systemctl is-active docker >/dev/null 2>&1; then
        handle_docker_permission_error
        return 1
    else
        handle_docker_not_running
        return 1
    fi
}

# Handle Docker permission issues
handle_docker_permission_error() {
    print_warning "Docker is running but you don't have permission to access it."
    echo ""
    echo "This is because you're not in the docker group in your current session."
    echo ""
    echo "Quick fix options:"
    echo "1) Run: newgrp docker"
    echo "   Then run: ./start.sh again"
    echo ""
    echo "2) Or run with sudo (not recommended):"
    echo "   sudo ./start.sh"
    echo ""
    echo "Permanent fix:"
    echo "1) Run: sudo usermod -aG docker $USER"
    echo "2) Log out and log back in"
}

# Handle Docker daemon not running
handle_docker_not_running() {
    print_warning "Docker daemon is not running."

    if ! systemctl list-units --full -all | grep -q "docker.service"; then
        print_error "Docker service not found. Please ensure Docker is installed."
        return 1
    fi

    echo "🔄 Attempting to start Docker daemon..."
    if sudo systemctl start docker; then
        sleep 2
        if systemctl is-active docker >/dev/null 2>&1; then
            print_success "Docker daemon started successfully!"
            if ! docker info > /dev/null 2>&1; then
                echo ""
                handle_docker_permission_error
                return 1
            fi
            return 0
        fi
    fi

    print_error "Failed to start Docker daemon."
    echo "Please run: sudo systemctl start docker"
}

# Check Docker permissions without daemon check
verify_docker_permissions() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would verify Docker permissions"
        return 0
    fi

    if docker ps &> /dev/null; then
        return 0
    fi

    if ! groups $USER | grep -q '\bdocker\b'; then
        print_warning "Docker permission issue detected."
        echo "   You're not in the docker group. To fix this:"
        echo "   1. Run: sudo usermod -aG docker $USER"
        echo "   2. Log out and back in (or run 'newgrp docker')"
        echo "   3. Run ./start.sh again"
        echo ""
        echo "   Alternatively, you can run this script with sudo (not recommended)."
        return 1
    fi
    return 0
}

# Get current Docker context
get_docker_context() {
    if [ "$DRY_RUN" = true ]; then
        echo "default"
        return
    fi
    docker context show 2>/dev/null || echo "default"
}

# Switch Docker context
switch_docker_context() {
    local target_context="$1"
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would switch to Docker context: $target_context"
        return 0
    fi
    echo "🔄 Switching to Docker context: $target_context..."
    if docker context use "$target_context" &>/dev/null; then
        print_success "Switched to $target_context context"
        return 0
    else
        print_error "Failed to switch to $target_context context"
        return 1
    fi
}

# ============================================================================
# Container Management Functions
# ============================================================================

# Extract host ports from Docker port format
extract_host_ports() {
    echo "$1" | grep -oE '0\.0\.0\.0:[0-9]+' | cut -d: -f2 | sort -u
}

# Get container status and ports
get_container_info() {
    local container_name="$1"

    if [ "$DRY_RUN" = true ]; then
        # Simulate some containers for dry-run testing
        case "$container_name" in
            ollama) echo "stopped" ;;
            open-webui) echo "stopped" ;;
            *) echo "not_found" ;;
        esac
        return
    fi

    local container_id=$(docker ps -aq --filter "name=$container_name" 2>/dev/null)

    if [ -z "$container_id" ]; then
        echo "not_found"
        return
    fi

    local status=$(docker ps --filter "name=$container_name" --format "{{.Status}}" 2>/dev/null)
    if [ -n "$status" ]; then
        local ports=$(docker ps --filter "name=$container_name" --format "{{.Ports}}" 2>/dev/null)
        local host_ports=$(extract_host_ports "$ports")
        echo "running|$status|$host_ports"
    else
        echo "stopped"
    fi
}

# Check containers across all Docker contexts
check_all_containers() {
    local current_context=$(get_docker_context)
    local contexts=$(docker context ls --format "{{.Name}}" 2>/dev/null)
    local found_containers=false
    local container_report=""

    # Check current context
    for service in "${!SERVICES[@]}"; do
        local info=$(get_container_info "$service")
        if [ "$info" != "not_found" ]; then
            found_containers=true
            container_report="${container_report}$(format_container_status "$service" "$info" "$current_context")\n"
        fi
    done

    # Check other contexts if on Linux
    if [ "$(uname)" = "Linux" ] && [ -n "$contexts" ]; then
        for context in $contexts; do
            if [ "$context" != "$current_context" ]; then
                switch_docker_context "$context" &>/dev/null
                for service in "${!SERVICES[@]}"; do
                    local info=$(get_container_info "$service")
                    if [ "$info" != "not_found" ]; then
                        found_containers=true
                        container_report="${container_report}$(format_container_status "$service" "$info" "$context")\n"
                    fi
                done
            fi
        done
        switch_docker_context "$current_context" &>/dev/null
    fi

    if [ "$found_containers" = true ]; then
        echo -e "$container_report"
        return 0
    else
        return 1
    fi
}

# Format container status for display
format_container_status() {
    local service="$1"
    local info="$2"
    local context="$3"

    IFS='|' read -r state status ports <<< "$info"

    local output="   • $service (${SERVICES[$service]})"
    [ "$context" != "$(get_docker_context)" ] && output="$output [context: $context]"

    case "$state" in
        running)
            output="$output: Running"
            [ -n "$status" ] && output="$output ($status)"
            [ -n "$ports" ] && output="$output - Ports: $ports"
            ;;
        stopped)
            output="$output: Stopped"
            ;;
    esac

    echo "$output"
}

# Clean up containers
cleanup_containers() {
    local cleanup_mode="$1"  # "remove" or "restart"

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would clean up existing containers..."
        for service in "${!SERVICES[@]}"; do
            echo "  [DRY-RUN] Would stop and remove $service"
        done
        if [ "$cleanup_mode" = "restart" ]; then
            echo "[DRY-RUN] Would preserve volumes and recreate with new config"
        else
            echo "[DRY-RUN] Would start fresh setup"
        fi
        return
    fi

    local contexts=$(docker context ls --format "{{.Name}}" 2>/dev/null)
    local current_context=$(get_docker_context)

    echo "🧹 Cleaning up existing containers..."

    # Clean up in all contexts if needed
    if [ "$(uname)" = "Linux" ] && [ -n "$contexts" ]; then
        for context in $contexts; do
            switch_docker_context "$context" &>/dev/null
            for service in "${!SERVICES[@]}"; do
                if docker ps -aq --filter "name=$service" 2>/dev/null | grep -q .; then
                    echo "  Stopping $service in context $context..."
                    docker stop "$service" 2>/dev/null || true
                    docker rm "$service" 2>/dev/null || true
                fi
            done
        done
        switch_docker_context "$current_context" &>/dev/null
    else
        # Just clean up in current context
        for service in "${!SERVICES[@]}"; do
            if docker ps -aq --filter "name=$service" 2>/dev/null | grep -q .; then
                echo "  Stopping $service..."
                docker stop "$service" 2>/dev/null || true
                docker rm "$service" 2>/dev/null || true
            fi
        done
    fi

    if [ "$cleanup_mode" = "restart" ]; then
        print_success "Containers removed (volumes preserved). Recreating with new config..."
    else
        print_success "Cleanup complete. Starting fresh setup..."
    fi
}

# ============================================================================
# GPU Support Functions
# ============================================================================

# Detect GPU and test Docker GPU support
detect_gpu_support() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would check for GPU support..."
        # Check if nvidia-smi exists for dry-run simulation
        if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
            echo "[DRY-RUN] NVIDIA GPU detected"
            echo "[DRY-RUN] Would test Docker GPU access"
            return 0  # Simulate GPU available for dry-run
        else
            echo "[DRY-RUN] No GPU detected"
            return 1
        fi
    fi

    local current_context=$(get_docker_context)

    # Skip GPU check for Docker Desktop on Linux
    if [ "$(uname)" = "Linux" ] && [ "$current_context" != "default" ] && [ -n "$current_context" ]; then
        print_warning "Skipping GPU check (Docker Desktop doesn't support GPU on Linux)"
        return 1
    fi

    # Check for NVIDIA GPU
    if ! command -v nvidia-smi &> /dev/null || ! nvidia-smi &> /dev/null; then
        return 1
    fi

    echo "🔍 NVIDIA GPU detected, checking Docker GPU support..."

    # Auto-detect CUDA version and select appropriate test image
    local cuda_version=$(nvidia-smi 2>/dev/null | grep "CUDA Version" | sed 's/.*CUDA Version: \([0-9.]*\).*/\1/' | head -1)
    local test_image=$(select_cuda_image "$cuda_version")

    # Test Docker GPU access
    if docker run --rm --gpus all "$test_image" nvidia-smi &> /dev/null 2>&1; then
        print_success "GPU is ready! Using GPU-accelerated setup..."
        return 0
    else
        echo ""
        print_warning "NVIDIA GPU detected but Docker can't access it!"
        echo "   This is usually because NVIDIA Container Toolkit is not installed."
        echo ""
        echo "   🔧 To fix this, run: ./fix-gpu.sh"
        echo ""
        echo "   For now, using CPU-only setup (models will run slower)."
        echo "   After fixing, run ./start.sh again for GPU acceleration."
        echo ""
        return 1
    fi
}

# Select appropriate CUDA image based on version
select_cuda_image() {
    local cuda_version="$1"
    if [ -z "$cuda_version" ]; then
        echo "$DEFAULT_CUDA_IMAGE"
        return
    fi

    local cuda_major_minor=$(echo "$cuda_version" | cut -d. -f1,2)
    case "$cuda_major_minor" in
        "11.4") echo "nvidia/cuda:11.4.3-base-ubuntu20.04" ;;
        "11.8") echo "nvidia/cuda:11.8.0-base-ubuntu20.04" ;;
        "12.0") echo "nvidia/cuda:12.0.1-base-ubuntu20.04" ;;
        "12.1") echo "nvidia/cuda:12.1.1-base-ubuntu20.04" ;;
        "12.2") echo "nvidia/cuda:12.2.2-base-ubuntu20.04" ;;
        *) echo "$DEFAULT_CUDA_IMAGE" ;;
    esac
}

# Handle Docker Desktop to native Docker switch for GPU
handle_docker_desktop_gpu() {
    local current_context=$(get_docker_context)

    if [ "$current_context" = "default" ] || [ -z "$current_context" ]; then
        return 0
    fi

    if ! command -v nvidia-smi &> /dev/null || ! nvidia-smi &> /dev/null; then
        print_info "Using Docker Desktop context (no GPU detected)"
        return 1
    fi

    echo "" >&2
    print_warning "You're using Docker Desktop on Linux with an NVIDIA GPU."
    echo "   Docker Desktop doesn't support GPU acceleration on Linux." >&2
    echo "" >&2
    echo "Would you like to switch to native Docker for GPU support?" >&2
    echo "1) Yes, switch to native Docker (recommended for GPU)" >&2
    echo "2) No, continue with Docker Desktop (CPU only)" >&2
    echo "" >&2
    read -p "Enter your choice (1-2): " choice

    case "$choice" in
        1)
            echo "" >&2
            if switch_docker_context "default"; then
                echo "🔍 Checking Docker daemon in native context..." >&2
                if ! check_docker_daemon; then
                    print_error "Cannot proceed without Docker daemon running."
                    exit 1
                fi
                verify_docker_permissions || true
                return 0
            fi
            ;;
        2)
            echo "" >&2
            print_info "Continuing with Docker Desktop (CPU-only mode)..."
            return 1
            ;;
        *)
            echo "Invalid choice. Continuing with current context..." >&2
            return 1
            ;;
    esac
}

# ============================================================================
# Service Health Checks
# ============================================================================

# Check service health status
check_service_health() {
    local service="$1"

    if [ "$DRY_RUN" = true ]; then
        echo "healthy"  # Simulate healthy for dry-run
        return
    fi

    local status=$(docker ps --filter "name=$service" --format "{{.Status}}" 2>/dev/null)

    if [ -z "$status" ]; then
        echo "not_running"
        return
    fi

    if echo "$status" | grep -q "healthy"; then
        echo "healthy"
    elif echo "$status" | grep -q "unhealthy"; then
        echo "unhealthy"
    elif echo "$status" | grep -q "starting"; then
        echo "starting"
    else
        echo "running"
    fi
}

# Display health check results
display_health_status() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would check container health status"
        return
    fi

    print_section "🔍 Checking container health..."

    sleep 10  # Wait for health checks to complete

    local all_healthy=true

    for service in ollama open-webui; do
        local health=$(check_service_health "$service")
        case "$health" in
            healthy|running)
                print_success "${SERVICES[$service]}: Healthy"
                ;;
            starting)
                echo "⏳ ${SERVICES[$service]}: Still starting up..."
                ;;
            unhealthy)
                print_warning "${SERVICES[$service]}: Running but unhealthy (checking logs...)"
                echo ""
                echo "🔍 Recent $service logs:"
                docker logs "$service" --tail 10 2>/dev/null || echo "Could not retrieve logs"
                echo ""
                echo "🔧 This is often a temporary startup issue. The service may still work."
                [ "$service" = "open-webui" ] && echo "   Try accessing http://localhost:$WEBUI_PORT in a few minutes."
                all_healthy=false
                ;;
            not_running)
                print_error "${SERVICES[$service]}: Not running properly"
                all_healthy=false
                ;;
        esac
    done

    echo ""
    if [ "$all_healthy" = true ]; then
        print_success "All services are healthy and ready! 🎉"
    else
        print_warning "Some services may have issues. Check the logs above."
    fi
}

# ============================================================================
# User Interaction Functions
# ============================================================================

# Get user's voice feature preference
get_voice_preference() {
    echo "🎤 Voice Features Setup:" >&2
    echo "1) Standard setup (text only)" >&2
    echo "2) Add Text-to-Speech (voice output)" >&2
    echo "" >&2
    read -p "Enter your choice (1-2): " voice_choice
    echo "" >&2

    case "$voice_choice" in
        2) echo "tts" ;;
        *) echo "standard" ;;
    esac
}

# Handle existing containers interaction
handle_existing_containers() {
    echo "" >&2
    print_warning "Existing containers detected that may conflict:"
    echo "$1" >&2
    echo "" >&2
    echo "What would you like to do?" >&2
    echo "1) Stop and remove existing containers, then start fresh" >&2
    echo "2) Try switching to existing containers with new configuration" >&2
    echo "3) Exit and let me handle this manually" >&2
    echo "" >&2
    read -p "Enter your choice (1-3): " choice

    case "$choice" in
        1)
            echo "" >&2
            cleanup_containers "remove"
            echo "recreate"
            ;;
        2)
            echo "" >&2
            cleanup_containers "restart"
            echo "restart"
            ;;
        3)
            echo "" >&2
            print_info "Exiting. You can manually stop containers with:"
            echo "   docker stop ollama open-webui tts-service" >&2
            echo "   docker rm ollama open-webui tts-service" >&2
            echo "   Then run ./start.sh again" >&2
            echo "exit_requested"
            ;;
        *)
            echo "Invalid choice. Exiting..." >&2
            echo "exit_requested"
            ;;
    esac
}

# Display next steps
display_next_steps() {
    local voice_mode="$1"

    print_section "📌 Next steps:"
    echo "   1. Open your browser and go to: http://localhost:$WEBUI_PORT"
    echo "   2. Create an account (first user becomes admin)"
    echo "   3. Download a model: Settings → Admin Panel → Models → Pull 'llama3.2:3b'"

    if [ "$voice_mode" = "tts" ]; then
        echo "   4. Configure TTS: Settings → Audio → TTS Settings"
        echo "   5. Start chatting with voice output!"
    else
        echo "   4. Start chatting!"
    fi

    echo ""
    echo "💡 Troubleshooting:"
    echo "   • If page doesn't load, wait 2-3 minutes and try again"
    echo "   • Check logs with: docker-compose logs -f"
    echo "   • Check container status with: docker ps"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_header

    # Step 1: Check Docker daemon
    if ! check_docker_daemon; then
        exit 1
    fi

    # Step 2: Handle Docker context and GPU on Linux
    if [ "$(uname)" = "Linux" ]; then
        local current_context=$(get_docker_context)
        if [ "$current_context" != "default" ] && [ -n "$current_context" ]; then
            handle_docker_desktop_gpu
        else
            verify_docker_permissions || exit 1
        fi
    fi

    # Step 3: Check for existing containers
    echo "🔍 Checking for existing containers..."
    local container_status=""
    if container_status=$(check_all_containers); then
        local action=$(handle_existing_containers "$container_status")
        if [ "$action" = "exit_requested" ]; then
            exit 0
        fi
        local compose_flags="-d --force-recreate"
    else
        print_success "No conflicting containers found."
        local compose_flags="-d"
    fi

    # Step 4: Get user preferences for optional features
    local voice_mode=$(get_voice_preference)

    # Step 5: Detect GPU support
    local gpu_available=false
    if detect_gpu_support; then
        gpu_available=true
    fi

    # Step 6: Build Docker Compose command
    local profiles="--profile base"

    if [ "$gpu_available" = true ]; then
        profiles="$profiles --profile gpu"
        echo "🚀 Starting with GPU acceleration..."
    else
        profiles="$profiles --profile cpu"
        echo "📝 Using CPU-only setup..."
        echo "   (This is fine, but models will run slower)"
    fi

    if [ "$voice_mode" = "tts" ]; then
        profiles="$profiles --profile tts"
        echo "🎤 Adding Text-to-Speech service..."
    fi

    # Step 7: Start services
    echo ""
    if [ "$DRY_RUN" = true ]; then
        echo "🚀 [DRY-RUN] Would start services..."
        echo "[DRY-RUN] Command: docker-compose $profiles up $compose_flags"
        echo "[DRY-RUN] Using profiles: base$([ "$gpu_available" = true ] && echo " + gpu" || echo " + cpu")$([ "$voice_mode" = "tts" ] && echo " + tts")"
        echo ""
        echo "[DRY-RUN] Services that would be started:"
        echo "  - open-webui (port $WEBUI_PORT)"
        echo "  - ollama (port $OLLAMA_PORT) - $([ "$gpu_available" = true ] && echo "GPU accelerated" || echo "CPU only")"
        [ "$voice_mode" = "tts" ] && echo "  - tts-service (port $TTS_PORT)"
        echo ""
        echo "[DRY-RUN] Complete! No actual containers were started."
        echo ""
        display_next_steps "$voice_mode"
    else
        echo "🚀 Starting services..."
        echo "Using profiles: base$([ "$gpu_available" = true ] && echo " + gpu" || echo " + cpu")$([ "$voice_mode" = "tts" ] && echo " + tts")"

        if ! docker-compose $profiles up $compose_flags; then
            print_error "Failed to start services. Check logs with: docker-compose logs"
            exit 1
        fi

        echo ""
        echo "⏳ Waiting for services to start..."
        sleep 5

        # Step 8: Check service health
        if docker-compose $profiles ps | grep -q "Up"; then
            display_health_status
            display_next_steps "$voice_mode"
        else
            echo ""
            print_error "Something went wrong. Running diagnostics..."
            docker-compose $profiles ps
            echo ""
            echo "Container logs:"
            echo "==============="
            docker-compose $profiles logs --tail 20
            echo ""
            echo "Try running: docker-compose $profiles logs -f"
            exit 1
        fi
    fi
}

# Run main function
main "$@"