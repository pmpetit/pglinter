#!/bin/bash

# PG Linter Documentation Server
# Quick script to serve the documentation locally

echo "🚀 Starting PG Linter Documentation Server"
echo "========================================="

# Check if site directory exists
if [ ! -d "/home/pmp/github/dblinter/site" ]; then
    echo "❌ Site directory not found. Building documentation..."
    cd /home/pmp/github/dblinter
    mkdocs build
fi

# Check if port 8080 is already in use
if netstat -tuln | grep -q ":8080 "; then
    echo "⚠️  Port 8080 is already in use"
    echo "🌐 Documentation is available at: http://localhost:8080"
    echo ""
    echo "📖 Available pages:"
    echo "   • Home: http://localhost:8080"
    echo "   • Installation: http://localhost:8080/INSTALL/"
    echo "   • Functions Reference: http://localhost:8080/functions/"
    echo "   • Quick Start: http://localhost:8080/tutorials/"
    echo "   • How-To Guides: http://localhost:8080/how-to/"
    echo "   • Examples: http://localhost:8080/examples/"
    echo "   • Development: http://localhost:8080/dev/"
    echo ""
else
    echo "🌐 Starting HTTP server on port 8080..."
    cd /home/pmp/github/dblinter/site

    # Start server in background
    nohup python3 -m http.server 8080 > /dev/null 2>&1 &
    SERVER_PID=$!

    echo "✅ Server started with PID: $SERVER_PID"
    echo ""
    echo "🌐 Documentation is now available at: http://localhost:8080"
    echo ""
    echo "📖 Available pages:"
    echo "   • Home: http://localhost:8080"
    echo "   • Installation: http://localhost:8080/INSTALL/"
    echo "   • Functions Reference: http://localhost:8080/functions/"
    echo "   • Quick Start: http://localhost:8080/tutorials/"
    echo "   • How-To Guides: http://localhost:8080/how-to/"
    echo "   • Examples: http://localhost:8080/examples/"
    echo "   • Development: http://localhost:8080/dev/"
    echo ""
    echo "🛑 To stop the server:"
    echo "   kill $SERVER_PID"
    echo "   or"
    echo "   pkill -f 'python3 -m http.server 8080'"
fi

echo ""
echo "🔧 Other options:"
echo "   • Development server: mkdocs serve"
echo "   • Rebuild docs: mkdocs build"
echo "   • Clean build: rm -rf site/ && mkdocs build"
