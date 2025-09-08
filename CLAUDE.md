# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Local AI deployment system using Docker Compose to run Ollama (LLM backend) and Open WebUI (chat interface) locally. The project is **optimized for Linux (Ubuntu) with NVIDIA GPUs**, featuring smart scripts for automatic setup and troubleshooting. While the Docker containers work on Mac and Windows, the advanced automation features (`start.sh`, `fix-gpu.sh`) are Linux-specific.

## Key Commands

### Starting and Stopping
```bash
# Start with automatic context/container detection and GPU support
./start.sh

# Stop the system
./stop.sh
# or
docker-compose down

# Start with explicit GPU support
docker-compose -f docker-compose.gpu.yml up -d

# Start without GPU (CPU only)
docker-compose up -d
```

### GPU and Docker Issues
```bash
# Fix GPU/Docker issues (handles NVIDIA Container Toolkit, Docker contexts, permissions)
./fix-gpu.sh

# Check GPU memory and loaded models
nvidia-smi
docker exec ollama ollama ps

# Unload models to free GPU memory
docker exec ollama ollama stop <model_name>
```

### Container Management
```bash
# Check container health
docker ps
docker logs open-webui --tail 20
docker logs ollama --tail 20

# View real-time logs
docker-compose logs -f

# Update containers to latest versions
docker-compose pull
docker-compose up -d

# Complete cleanup (removes all data and models)
docker-compose down -v
```

## Architecture

### Docker Services
1. **ollama**: LLM backend service (port 11434)
   - Manages model downloads and execution
   - Handles GPU acceleration when available
   - Auto-unloads models after 5 minutes of inactivity
   - Stores models in `ollama-data` volume

2. **open-webui**: Web interface (port 3000)
   - Provides ChatGPT-like interface
   - Connects to Ollama backend
   - Manages user accounts and chat history
   - Stores data in `open-webui-data` volume

### Critical Scripts

#### start.sh
- Detects and handles Docker contexts (Docker Desktop vs native Docker)
- Checks for conflicting containers across all contexts
- Prompts for GPU support on Linux with NVIDIA hardware
- Performs health checks on containers
- Handles container cleanup and port conflicts

#### fix-gpu.sh
- Auto-detects system configuration (GPU, drivers, CUDA version, OS)
- Installs NVIDIA Container Toolkit
- Fixes library linking issues for older drivers
- Switches from Docker Desktop to native Docker on Linux
- Manages user Docker group permissions

### Docker Context Handling
The scripts handle complex Docker context scenarios:
- Docker Desktop doesn't support GPU on Linux
- Containers may exist in different contexts blocking ports
- Automatic context switching when needed for GPU support

## Important Configuration Details

### Environment Variables
- `OLLAMA_BASE_URL`: Connection between WebUI and Ollama
- `WEBUI_SECRET_KEY`: Should be changed in production
- `OLLAMA_KEEP_ALIVE`: Controls model unload timeout (default 5m)

### GPU Support Requirements
- NVIDIA GPU with NVIDIA Container Toolkit
- Native Docker context (not Docker Desktop on Linux)
- User must be in docker group
- Correct CUDA container image tags (e.g., `nvidia/cuda:11.4.3-base-ubuntu20.04`)

### Health Checks
- Open WebUI may show "unhealthy" during startup (normal)
- Health checks occur after 15 seconds of startup
- Containers may need 2-3 minutes to fully initialize

## Common Issues and Solutions

### Port Conflicts
- Scripts check for ports 11434 and 3000 usage
- Automatically detect containers in other Docker contexts
- Clean up containers across all contexts when needed

### GPU Not Detected
- Must use native Docker context on Linux
- NVIDIA Container Toolkit must be installed
- User must be in docker group
- Run `./fix-gpu.sh` to automate fixes

### Container Health Issues
- "Unhealthy" status often temporary during startup
- Database initialization can take time on first run
- Scripts show logs automatically when issues detected