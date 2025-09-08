# Local AI with Open WebUI - Beginner's Guide

Run AI models locally on your computer with a beautiful chat interface - no cloud needed!

> **Note**: This repository is optimized for **Linux (Ubuntu)** with **NVIDIA GPUs**. The smart scripts (`start.sh`, `fix-gpu.sh`) are designed for quick setup on Linux systems. While the Docker containers work on Mac and Windows, you'll need to use the manual Docker commands on those platforms.

## What is this?

This project lets you:
- **Run AI models locally** - Everything runs on your computer, completely private
- **Chat with various LLMs** - Use models like Llama 3, Mistral, Phi, and more
- **Beautiful interface** - Open WebUI provides a ChatGPT-like experience
- **No coding required** - Just a few commands to get started

## Prerequisites

You only need:
1. **Docker Desktop** installed ([Download here](https://www.docker.com/products/docker-desktop/))
2. At least **8GB of RAM** (16GB recommended)
3. **10GB of free disk space** for models

Optional for faster performance:
- NVIDIA GPU with 6GB+ VRAM

## Quick Start (5 minutes!)

### Step 1: Start the System

**For Linux users:**
Open a terminal in this folder and run:

```bash
# Start everything (automatically handles GPU setup, Docker contexts, and container conflicts)
./start.sh
```

The smart start script will:
- Detect your GPU and offer GPU acceleration
- Handle Docker Desktop vs native Docker contexts
- Clean up any conflicting containers
- Check container health after startup

**For Mac/Windows users:**
Use the manual Docker commands:

```bash
# For GPU support (Linux only)
docker-compose -f docker-compose.gpu.yml up -d

# For CPU only (all platforms)
docker-compose up -d
```

That's it! The system is now running.

### Step 2: Open the Chat Interface

Open your browser and go to: **http://localhost:3000**

1. **Create an account** (first user becomes admin)
2. Click **Sign up** with any email (stays local, not sent anywhere)

### Step 3: Download Your First Model

In the Open WebUI interface:

1. Click the **⚙️ Settings** icon (usually top-right corner)
2. Go to **"Admin Panel"** → **"Settings"** → **"Models"**
3. In the **"Pull a model from Ollama.com"** section:
   - Enter a model name: `llama3.2:3b` (small and fast)
   - Or for better quality: `llama3.2:latest` 
4. Click **"Pull Model"**
5. Wait for download (shows progress in the interface)

### Step 4: Start Chatting!

Once the model downloads:
1. Select it from the model dropdown (top of chat)
2. Type your message
3. Press Enter
4. Watch the AI respond!

## Available Models

Here are popular models to try (add them via **Settings** → **Admin Panel** → **Models**):

### Small & Fast (Under 4GB)
- `llama3.2:3b` - Good for basic tasks
- `phi3:mini` - Microsoft's efficient model
- `gemma2:2b` - Google's small model

### Balanced (4-8GB)
- `llama3.2:latest` - Best overall
- `mistral:7b` - Great for coding
- `qwen2.5:7b` - Strong multilingual

### Large & Powerful (8GB+)
- `llama3.1:8b` - Very capable
- `mixtral:8x7b` - Excellent but needs 26GB
- `deepseek-coder-v2:16b` - Best for programming

## GPU Support (Faster Performance!)

If you have an NVIDIA GPU, the `./start.sh` script will automatically detect it and offer GPU acceleration. If you need to troubleshoot GPU issues:

```bash
# Fix GPU setup issues (handles everything automatically)
./fix-gpu.sh
```

This script will:
- Install NVIDIA Container Toolkit if needed  
- Fix Docker context issues (Docker Desktop → native Docker)
- Handle user permissions
- Create proper library links
- Test GPU access

**Manual GPU setup:**
```bash
# Stop current setup and start with GPU
docker-compose down
docker-compose -f docker-compose.gpu.yml up -d
```

## Common Commands

**Recommended (using smart scripts):**
```bash
# Start the system (with automatic setup)
./start.sh

# Stop the system  
./stop.sh

# Fix GPU issues
./fix-gpu.sh
```

**Manual commands:**
```bash
# Start manually
docker-compose up -d

# Stop manually
docker-compose down

# View logs if something seems wrong
docker-compose logs -f

# Restart everything
docker-compose restart

# Update to latest versions
docker-compose pull
docker-compose up -d
```

## Troubleshooting

### "Connection refused" or can't access localhost:3000
```bash
# Check if containers are running
docker-compose ps

# Restart them
docker-compose restart
```

### Models download slowly
- This is normal for first download
- Models are saved, so only downloaded once
- Try smaller models first (ones with `:3b` tag)

### "Out of memory" errors
- Try smaller models (`:3b` or `:mini` versions)
- Close other applications
- Restart Docker Desktop

### GPU not being used
1. Make sure you have NVIDIA GPU
2. Install NVIDIA Container Toolkit:
   ```bash
   # Check if GPU is visible to Docker
   docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
   ```

## Tips for Beginners

1. **Start small**: Use `llama3.2:3b` first to test everything works
2. **Be patient**: First model download takes time (like downloading a movie)
3. **Models are saved**: Once downloaded, models start instantly next time
4. **Privacy**: Everything runs locally - your chats never leave your computer
5. **Experiment**: Try different models for different tasks

## What Can You Do?

- **Writing**: Essays, emails, creative writing
- **Coding**: Get help with programming
- **Learning**: Ask questions, get explanations
- **Translation**: Many models support multiple languages
- **Analysis**: Summarize documents, analyze text
- **Brainstorming**: Generate ideas, solve problems

## Data & Privacy

- **100% Local**: No data sent to cloud services
- **Your data**: Chats saved locally in Docker volumes
- **Delete anytime**: Run `docker-compose down -v` to remove everything

## Getting Help

- **Open WebUI Docs**: https://docs.openwebui.com/
- **Ollama Models**: https://ollama.com/library
- **Issues**: Check the Troubleshooting section above

## 🛰️ MCP Integration & Home Automation

Transform your Local AI into a powerful home automation hub using **Model Context Protocol (MCP)**! MCP enables your AI to control smart home devices, manage calendars, integrate with APIs, and automate tasks - all while keeping everything local and private.

**Perfect for:**
- 🏡 Smart home control (lights, thermostat, security)
- 📅 Calendar and task management
- 🌐 Real-time data (weather, traffic, news)
- 🔌 Custom API integrations
- 🛠️ Extensible automation without modifying core AI

**[📖 Complete MCP Integration Guide →](MCP_INTEGRATION.md)**

## Advanced Users

Once comfortable, you can:
- Modify `docker-compose.yml` for more settings
- Use the Ollama API directly at `http://localhost:11434`
- Import custom models
- Set up model-specific parameters
- Connect other applications to Ollama

## Stop & Cleanup

**Recommended:**
```bash
# Stop the system (keeps your data)
./stop.sh
```

**Manual cleanup:**
```bash
# Stop containers (keeps your data)
docker-compose down

# Remove everything including models (complete cleanup)
docker-compose down -v
```

---

Enjoy your private AI assistant! Remember: everything runs on your computer, so your conversations stay completely private.