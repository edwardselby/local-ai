# 🚀 QUICK START - 3 Steps Only!

> **Note**: Optimized for **Linux (Ubuntu) with NVIDIA GPU**. Mac/Windows users should use the manual Docker commands.

## Step 1: Start
**Linux:**
```bash
./start.sh
```
**Mac/Windows:**
```bash
docker-compose up -d
```

## Step 2: Open Browser
Go to: **http://localhost:3000**
- Sign up (any email works, stays local)

## Step 3: Get a Model
In the interface:
1. Click **⚙️ Settings**
2. Go to **Admin Panel** → **Models**  
3. In "Pull a model" section, enter: `llama3.2:3b`
4. Click **Pull Model**
5. Wait for download, then start chatting!

## To Stop
```bash
./stop.sh
```
Or: `docker-compose down`

---
That's it! For more details, see README.md