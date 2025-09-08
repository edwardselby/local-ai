#!/bin/bash

# Enhanced stop script that handles all profiles and Docker contexts

echo "🛑 Stopping Local AI services..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "⚠️  Docker is not running. Services may already be stopped."
    exit 0
fi

# Get current Docker context
CURRENT_CONTEXT=$(docker context show 2>/dev/null || echo "default")
echo "📍 Current Docker context: $CURRENT_CONTEXT"

# Get all available contexts
CONTEXTS=$(docker context ls --format "{{.Name}}" 2>/dev/null)

# Function to check if a container exists and is running
check_container() {
    local container_name=$1
    if docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^${container_name}$"; then
        local status=$(docker inspect -f '{{.State.Running}}' "$container_name" 2>/dev/null)
        if [ "$status" = "true" ]; then
            echo "   ✓ Found running container: $container_name"
            return 0
        else
            echo "   ○ Found stopped container: $container_name"
            return 1
        fi
    fi
    return 2
}

# Function to stop containers in a specific context
stop_containers_in_context() {
    local context=$1
    local found_any=false
    
    echo ""
    echo "🔍 Checking context: $context"
    
    # Check for containers
    check_container "ollama"
    local ollama_status=$?
    
    check_container "open-webui"
    local webui_status=$?
    
    check_container "tts-service"
    local tts_status=$?
    
    # If any containers found, try to stop them
    if [ $ollama_status -le 1 ] || [ $webui_status -le 1 ] || [ $tts_status -le 1 ]; then
        found_any=true
        
        echo "   🛑 Stopping containers in context '$context'..."
        
        # Try docker-compose stop with all profiles first (only stops, doesn't remove)
        docker-compose --profile base --profile cpu --profile gpu --profile tts stop 2>/dev/null
        
        # Also try to stop individual containers directly
        if [ $ollama_status -eq 0 ]; then
            docker stop ollama 2>/dev/null && echo "     ✓ Stopped ollama" || echo "     ⚠️  Could not stop ollama"
        fi
        
        if [ $webui_status -eq 0 ]; then
            docker stop open-webui 2>/dev/null && echo "     ✓ Stopped open-webui" || echo "     ⚠️  Could not stop open-webui"
        fi
        
        if [ $tts_status -eq 0 ]; then
            docker stop tts-service 2>/dev/null && echo "     ✓ Stopped tts-service" || echo "     ⚠️  Could not stop tts-service"
        fi
    else
        echo "   ℹ️  No Local AI containers found in this context"
    fi
    
    return $([ "$found_any" = true ] && echo 0 || echo 1)
}

# Track if we found containers in any context
FOUND_IN_ANY_CONTEXT=false

# Check current context first
stop_containers_in_context "$CURRENT_CONTEXT"
if [ $? -eq 0 ]; then
    FOUND_IN_ANY_CONTEXT=true
fi

# Check other contexts if they exist
if [ -n "$CONTEXTS" ]; then
    for context in $CONTEXTS; do
        if [ "$context" != "$CURRENT_CONTEXT" ]; then
            # Switch to the other context
            docker context use "$context" &>/dev/null
            if [ $? -eq 0 ]; then
                stop_containers_in_context "$context"
                if [ $? -eq 0 ]; then
                    FOUND_IN_ANY_CONTEXT=true
                fi
            fi
        fi
    done
    
    # Switch back to original context
    echo ""
    echo "🔄 Switching back to original context: $CURRENT_CONTEXT"
    docker context use "$CURRENT_CONTEXT" &>/dev/null
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FOUND_IN_ANY_CONTEXT" = true ]; then
    echo "✅ Local AI services have been stopped."
    echo ""
    echo "📝 Note: Containers are stopped but not removed."
    echo "   • Your models and chat history are preserved"
    echo "   • Run ./start.sh to start again"
    echo "   • Run 'docker-compose down' to remove containers"
    echo "   • Run 'docker-compose down -v' to remove everything including data"
else
    echo "ℹ️  No Local AI containers were found in any Docker context."
    echo ""
    echo "💡 If you were expecting containers:"
    echo "   • They may have already been stopped"
    echo "   • Check manually with: docker ps -a"
fi

echo ""

# Final check in current context for any remaining running containers
REMAINING=$(docker ps --filter "name=ollama" --filter "name=open-webui" --filter "name=tts-service" -q 2>/dev/null)
if [ -n "$REMAINING" ]; then
    echo "⚠️  Warning: Some containers may still be running in current context."
    echo "   To force stop: docker stop ollama open-webui tts-service"
    echo ""
fi