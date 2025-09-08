# 🛰️ MCP Integration Guide
## Model Context Protocol for Home Automation & Custom Integrations

This guide explains how to extend your Local AI system with custom integrations using the Model Context Protocol (MCP). MCP enables your AI to interact with external APIs, smart home devices, databases, and custom services - making it perfect for home automation and task management systems.

## 🏠 What is MCP?

**Model Context Protocol (MCP)** is an open standard developed by Anthropic that allows AI models to securely access external data sources and tools. Think of it as a bridge between your AI and the real world.

### Why MCP for Home Automation?

- **🔌 Universal Integration**: Connect to any API, database, or service
- **🏡 Smart Home Control**: Control lights, thermostats, security systems
- **📅 Task Management**: Integrate calendars, todo lists, shopping lists  
- **🌐 Real-time Data**: Weather, traffic, news, stock prices
- **🔒 Secure & Private**: Everything runs locally on your network
- **🛠️ Extensible**: Add new capabilities without modifying core AI

## 🎯 Home Automation Use Cases

### **Kitchen Assistant**
- **"Add milk to shopping list"** → Updates grocery app
- **"Set timer for 10 minutes"** → Controls smart timer/display
- **"What's the weather today?"** → Fetches local weather
- **"Show today's meal plan"** → Reads from meal planning app

### **Smart Home Control**  
- **"Turn off living room lights"** → Controls smart bulbs
- **"Set thermostat to 72 degrees"** → Adjusts HVAC system
- **"Is the front door locked?"** → Checks security system
- **"Show security camera feeds"** → Displays camera streams

### **Personal Assistant**
- **"What's on my calendar?"** → Reads calendar events
- **"Add meeting to tomorrow at 2pm"** → Creates calendar entries
- **"Read my emails"** → Fetches email summaries
- **"What's my commute time?"** → Checks traffic APIs

### **Entertainment & Media**
- **"Play my morning playlist"** → Controls music system
- **"What movies are playing nearby?"** → Queries theater APIs
- **"Record tonight's game"** → Programs DVR/streaming

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Open WebUI    │◄──►│  MCPO Proxy  │◄──►│   MCP Server    │
│   (Your AI)     │    │  (Converter) │    │ (Custom Logic)  │
└─────────────────┘    └──────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │   External APIs     │
                    │ • Smart Home Hub    │
                    │ • Calendar/Tasks    │
                    │ • Weather Service   │
                    │ • Database         │
                    └─────────────────────┘
```

## 🚀 Quick Setup Guide

### **Step 1: Install MCP Proxy**

```bash
# Install MCPO (MCP-to-OpenAPI Proxy)
pip install mcpo

# Or using uvx for isolated installation
uvx install mcpo
```

### **Step 2: Create Simple MCP Server**

Create a basic MCP server for testing:

```python
# simple_mcp_server.py
#!/usr/bin/env python3
import json
import sys
from datetime import datetime

def handle_request(request):
    method = request.get('method')
    
    if method == 'tools/list':
        return {
            'tools': [
                {
                    'name': 'get_time',
                    'description': 'Get current date and time',
                    'inputSchema': {
                        'type': 'object',
                        'properties': {},
                        'required': []
                    }
                },
                {
                    'name': 'add_to_shopping_list', 
                    'description': 'Add item to shopping list',
                    'inputSchema': {
                        'type': 'object',
                        'properties': {
                            'item': {'type': 'string', 'description': 'Item to add'}
                        },
                        'required': ['item']
                    }
                }
            ]
        }
    
    elif method == 'tools/call':
        name = request['params']['name']
        args = request['params'].get('arguments', {})
        
        if name == 'get_time':
            return {
                'content': [
                    {
                        'type': 'text',
                        'text': f"Current time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                    }
                ]
            }
        
        elif name == 'add_to_shopping_list':
            item = args.get('item', '')
            # Here you'd integrate with your actual shopping list API
            return {
                'content': [
                    {
                        'type': 'text', 
                        'text': f"Added '{item}' to shopping list"
                    }
                ]
            }
    
    return {'error': 'Unknown method'}

# Basic MCP server loop
if __name__ == '__main__':
    for line in sys.stdin:
        try:
            request = json.loads(line.strip())
            response = handle_request(request)
            print(json.dumps(response))
            sys.stdout.flush()
        except Exception as e:
            print(json.dumps({'error': str(e)}))
            sys.stdout.flush()
```

### **Step 3: Start MCP Proxy Server**

```bash
# Start MCPO proxy with your MCP server
uvx mcpo --port 8080 --api-key "home-automation-key" -- python simple_mcp_server.py

# Server will be available at http://localhost:8080
# Documentation at http://localhost:8080/docs
```

### **Step 4: Connect to Open WebUI**

1. **Open WebUI**: http://localhost:3000
2. **Settings** → **Admin Panel** → **Tools** → **Add Tool**
3. **Configure Tool**:
   - **Name**: "Home Automation"
   - **URL**: `http://localhost:8080`
   - **API Key**: `home-automation-key`
4. **Save and Test**

## 🏡 Advanced Home Automation Examples

### **Smart Home Hub Integration**

```python
# home_assistant_mcp.py - Home Assistant integration
import requests

class HomeAssistantMCP:
    def __init__(self, ha_url, ha_token):
        self.ha_url = ha_url
        self.headers = {
            'Authorization': f'Bearer {ha_token}',
            'Content-Type': 'application/json'
        }
    
    def turn_on_light(self, entity_id):
        response = requests.post(
            f'{self.ha_url}/api/services/light/turn_on',
            headers=self.headers,
            json={'entity_id': entity_id}
        )
        return f"Turned on {entity_id}"
    
    def get_sensor_data(self, sensor_id):
        response = requests.get(
            f'{self.ha_url}/api/states/{sensor_id}',
            headers=self.headers
        )
        data = response.json()
        return f"{sensor_id}: {data['state']} {data['attributes'].get('unit_of_measurement', '')}"
```

### **Calendar & Task Management**

```python
# calendar_mcp.py - Google Calendar integration
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build

class CalendarMCP:
    def __init__(self, credentials_file):
        creds = Credentials.from_service_account_file(credentials_file)
        self.service = build('calendar', 'v3', credentials=creds)
    
    def get_todays_events(self):
        # Implementation for fetching today's calendar events
        pass
    
    def create_event(self, title, start_time, duration):
        # Implementation for creating calendar events
        pass
```

### **IoT Device Control**

```python
# iot_mcp.py - Generic IoT device control
import paho.mqtt.client as mqtt

class IoTDeviceMCP:
    def __init__(self, mqtt_broker, mqtt_port=1883):
        self.client = mqtt.Client()
        self.client.connect(mqtt_broker, mqtt_port, 60)
    
    def send_command(self, device_topic, command):
        self.client.publish(device_topic, command)
        return f"Sent '{command}' to {device_topic}"
    
    def get_device_status(self, status_topic):
        # Implementation for reading device status
        pass
```

## 🔧 Integration with Your Local AI Setup

### **Add MCP to Docker Compose** (Optional)

```yaml
# Add to your docker-compose.yml
services:
  mcp-proxy:
    image: python:3.11-slim
    container_name: mcp-proxy
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./mcp-servers:/app/mcp-servers
      - ./mcp-configs:/app/configs
    working_dir: /app
    command: >
      bash -c "pip install mcpo && 
               uvx mcpo --port 8080 --api-key home-automation -- 
               python /app/mcp-servers/your_mcp_server.py"
    profiles:
      - mcp
```

### **Using Profiles for MCP**

```bash
# Start with MCP integration
./start.sh
# Choose voice features + MCP when prompted (future enhancement)

# Or manually start with MCP profile
docker-compose --profile base --profile gpu --profile tts --profile mcp up -d
```

## 📚 Available MCP Servers & Tools

### **Pre-built MCP Servers**
- **[mcp-server-time](https://github.com/modelcontextprotocol/servers/tree/main/src/time)** - Date/time utilities
- **[mcp-server-filesystem](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem)** - File operations  
- **[mcp-server-web-search](https://github.com/modelcontextprotocol/servers/tree/main/src/web-search)** - Web search capabilities
- **[mcp-server-slack](https://github.com/modelcontextprotocol/servers/tree/main/src/slack)** - Slack integration
- **[mcp-server-github](https://github.com/modelcontextprotocol/servers/tree/main/src/github)** - GitHub API access

### **Community MCP Servers**
- **Home Assistant MCP** - Smart home control
- **Todoist MCP** - Task management  
- **Weather API MCP** - Weather data
- **Music Control MCP** - Spotify/Apple Music
- **Security System MCP** - Alarm/camera control

## 🛠️ Development Resources

### **Official Documentation**
- **[Model Context Protocol](https://modelcontextprotocol.io/)** - Official MCP documentation
- **[Open WebUI MCP Guide](https://docs.openwebui.com/openapi-servers/mcp/)** - Integration instructions
- **[MCPO GitHub](https://github.com/open-webui/mcpo)** - Proxy server repository
- **[MCP Server Examples](https://github.com/modelcontextprotocol/servers)** - Official server implementations

### **Development Tools**
- **[MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)** - For TypeScript/JavaScript
- **[MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)** - For Python development
- **[MCP Inspector](https://github.com/modelcontextprotocol/inspector)** - Development and debugging tool

### **Testing & Debugging**
```bash
# Test MCP server directly
echo '{"method": "tools/list", "params": {}}' | python your_mcp_server.py

# Test via MCPO proxy
curl -X POST http://localhost:8080/tools/call \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{"name": "get_time", "arguments": {}}'
```

## 🏠 Home Automation Project Ideas

### **Phase 1: Basic Integration**
1. **Time & Weather Server** - Current time, weather forecasts
2. **Simple Task List** - Add/remove tasks via voice
3. **Smart Light Control** - Basic on/off commands

### **Phase 2: Advanced Features**  
1. **Calendar Integration** - Schedule management
2. **Shopping List Sync** - Multi-device shopping lists
3. **Security Monitoring** - Door/window sensors

### **Phase 3: Full Home Automation**
1. **HVAC Control** - Temperature scheduling
2. **Energy Monitoring** - Usage tracking and optimization
3. **Automated Routines** - Morning/evening automation
4. **Voice-Controlled Media** - Entertainment system control

### **Phase 4: AI-Driven Automation**
1. **Predictive Control** - Learn patterns and automate
2. **Context-Aware Actions** - Location/time-based automation  
3. **Multi-Modal Interface** - Voice + visual + gesture control
4. **External Service Integration** - Delivery tracking, appointment scheduling

## 🚨 Security Considerations

### **Network Security**
- **Local Network Only**: Keep MCP servers on local network
- **API Key Authentication**: Always use API keys for MCPO
- **HTTPS/TLS**: Use secure connections for external APIs
- **Firewall Rules**: Restrict external access to MCP ports

### **Data Privacy**
- **Local Processing**: Keep sensitive data on local network
- **Encrypted Storage**: Encrypt configuration files and tokens
- **Access Control**: Implement user-based permissions
- **Audit Logging**: Log all MCP interactions for security review

### **Best Practices**
```bash
# Secure MCP server configuration
uvx mcpo --port 8080 \
  --api-key "$(openssl rand -base64 32)" \
  --cors-origins "http://localhost:3000" \
  --rate-limit 100 \
  -- python secure_mcp_server.py
```

## 🔗 Next Steps

### **Getting Started**
1. **Install MCPO**: `pip install mcpo`
2. **Create Simple Server**: Copy the example above
3. **Test Integration**: Connect to your Open WebUI
4. **Expand Functionality**: Add your specific use cases

### **Advanced Development**
1. **Study MCP Protocol**: Understand the full specification
2. **Build Custom Servers**: Create servers for your specific needs
3. **Contribute to Community**: Share your MCP servers with others
4. **Scale Your System**: Deploy across multiple devices/locations

### **Home Automation Roadmap**
1. **Start Simple**: Basic time/weather/tasks
2. **Add Smart Home**: Light/temperature control
3. **Integrate Services**: Calendar, shopping, entertainment  
4. **Automate Routines**: Create intelligent automation
5. **Scale & Share**: Help others build similar systems

## 💡 Community & Support

- **[MCP GitHub Discussions](https://github.com/modelcontextprotocol/specification/discussions)** - Community support
- **[Open WebUI Discord](https://discord.gg/5rJgQTnV4s)** - Integration help
- **[Home Assistant Community](https://community.home-assistant.io/)** - Smart home integration
- **[r/homeautomation](https://reddit.com/r/homeautomation)** - Ideas and inspiration

---

**Ready to transform your Local AI into a powerful home automation hub?** Start with the simple examples above and gradually build your perfect smart home assistant! 🏠🤖✨