#!/bin/bash

# Simple stop script

echo "🛑 Stopping Local AI..."
docker-compose down

echo ""
echo "✅ Local AI has been stopped."
echo ""
echo "📝 Note: Your models and chat history are preserved."
echo "   Run ./start.sh to start again anytime!"
echo ""
echo "💡 To completely remove everything (including downloaded models):"
echo "   Run: docker-compose down -v"