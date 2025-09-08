# 🎤 Voice Features Setup Guide

This guide explains how to add voice capabilities to your Local AI setup.

## Current Voice Capabilities

### ✅ Speech-to-Text (Already Available)
- **Built-in**: Open WebUI has speech-to-text built-in using your browser's Web Speech API
- **Privacy**: Runs locally in your browser, no external services
- **Usage**: Click the microphone button in the chat interface
- **Requirements**: HTTPS connection for microphone access (works on localhost)

### 🎤 Text-to-Speech (Optional Add-on)
- **External Service**: Uses openedai-speech container for TTS
- **Fast & Local**: Piper TTS engine (CPU-based, very fast)
- **Multiple Voices**: 6 different voice options
- **Privacy**: Completely local, no cloud services

## Quick Setup

### Option 1: Start with TTS from Beginning
```bash
./start.sh
# Choose option 2 when prompted for voice features
```

### Option 2: Add TTS to Existing Setup
```bash
# Stop current setup
./stop.sh

# Restart with TTS
./start.sh
# Choose option 2 when prompted
```

## TTS Configuration in Open WebUI

After starting with TTS enabled:

1. **Open the interface**: http://localhost:3000
2. **Go to Settings**: Click the ⚙️ Settings icon
3. **Navigate to Audio**: Settings → Audio → TTS Settings
4. **Configure TTS endpoint**:
   - **API Base URL**: `http://tts-service:8000/v1`
   - **API Key**: `sk-dummy` (any dummy key works)
   - **Model**: Select `tts-1`
5. **Choose a voice**:
   - `alloy` - Balanced, clear voice
   - `echo` - Warm, friendly voice
   - `fable` - British accent, expressive
   - `onyx` - Deep, authoritative voice
   - `nova` - Bright, energetic voice
   - `shimmer` - Soft, pleasant voice

## Available Docker Configurations

### TTS Files Created
- `docker-compose.tts.yml` - TTS with CPU-only setup
- `docker-compose.tts.gpu.yml` - TTS with GPU support

### Services Included
1. **ollama**: LLM backend (port 11434)
2. **open-webui**: Chat interface (port 3000)
3. **tts-service**: Text-to-Speech API (port 8000)

## Voice Quality & Performance

### Speech-to-Text
- **Accuracy**: Depends on your browser and microphone quality
- **Languages**: Supports multiple languages (browser-dependent)
- **Latency**: Real-time, no noticeable delay

### Text-to-Speech
- **Engine**: Piper TTS (neural voices)
- **Speed**: Very fast generation (~200ms for typical responses)
- **Quality**: Natural-sounding neural voices
- **Languages**: English (US/UK voices available)

## Troubleshooting Voice Issues

### Speech-to-Text Not Working
1. **Check microphone permissions**: Allow microphone access in browser
2. **Use HTTPS**: Voice features require secure connection (localhost works)
3. **Try different browser**: Chrome/Edge work best for speech recognition

### Text-to-Speech Not Working
1. **Check TTS service**: `docker logs tts-service`
2. **Verify endpoint**: Make sure API Base URL is `http://tts-service:8000/v1`
3. **Test TTS service directly**:
   ```bash
   curl -X POST http://localhost:8000/v1/audio/speech \
     -H "Content-Type: application/json" \
     -d '{"model": "tts-1", "input": "Hello world", "voice": "alloy"}'
   ```

### Container Issues
```bash
# Check all containers are running
docker ps

# Check TTS service health
docker exec tts-service curl -f http://localhost:8000/v1/models

# View logs if issues
docker logs tts-service --tail 20
```

## Advanced TTS Options

### Voice Customization
The TTS service supports different Piper voice models. Current voice mappings:
- `alloy`: en_US-lessac-medium
- `echo`: en_US-ryan-medium  
- `fable`: en_GB-jenny_dioco-medium
- `onyx`: en_US-ryan-low
- `nova`: en_US-lessac-high
- `shimmer`: en_US-lessac-medium

### Performance Tuning
- **CPU Usage**: TTS runs on CPU, no GPU required
- **Memory**: ~500MB additional for TTS service
- **Speed**: Typical response time <500ms for most text lengths

## Manual Commands

### Start specific configurations
```bash
# CPU-only with TTS
docker-compose -f docker-compose.tts.yml up -d

# GPU with TTS  
docker-compose -f docker-compose.tts.gpu.yml up -d

# Stop all services
docker-compose -f docker-compose.tts.yml down
# or
docker-compose -f docker-compose.tts.gpu.yml down
```

### TTS Service Management
```bash
# Restart just TTS service
docker restart tts-service

# Update TTS service
docker pull ghcr.io/matatonic/openedai-speech:latest
docker-compose -f docker-compose.tts.yml up -d --force-recreate tts-service
```

## Privacy & Security

- **Speech-to-Text**: Uses browser's built-in API, no data sent externally
- **Text-to-Speech**: Runs completely locally, no external API calls
- **Data Storage**: All voice data stays on your machine
- **Network**: No internet connection required for voice features

---

## Quick Reference

| Feature | Status | Privacy | Speed |
|---------|--------|---------|--------|
| Speech-to-Text | ✅ Built-in | 🔒 Local browser | ⚡ Real-time |
| Text-to-Speech | 🎤 Optional | 🔒 Local container | ⚡ Very fast |

**Need help?** Check the main [README.md](README.md) or run `./start.sh` with option 2 for guided setup.