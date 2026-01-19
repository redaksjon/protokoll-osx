#!/bin/bash
# Debug script for Protokoll MCP server issues

echo "🔍 Protokoll MCP Server Debug"
echo "=============================="
echo ""

# Check if server binary exists
SERVER_PATH="$HOME/.nvm/versions/node/v24.8.0/bin/protokoll-mcp"
if [ -f "$SERVER_PATH" ]; then
    echo "✅ Server binary found: $SERVER_PATH"
else
    echo "❌ Server binary NOT found at: $SERVER_PATH"
    echo "   Try: cd /Users/tobrien/gitw/redaksjon/protokoll && npm run build"
    exit 1
fi

# Check if binary is executable
if [ -x "$SERVER_PATH" ]; then
    echo "✅ Server binary is executable"
else
    echo "❌ Server binary is NOT executable"
    echo "   Try: chmod +x $SERVER_PATH"
    exit 1
fi

echo ""
echo "Testing server startup..."
echo "========================"

# Try to run server with macOS-compatible timeout
# Use sleep in background to simulate timeout
(sleep 2; kill $SERVERPID 2>/dev/null) &
KILLERpid=$!

"$SERVER_PATH" <<EOF &
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"TestClient","version":"1.0.0"}}}
EOF
SERVERPID=$!

wait $SERVERPID 2>/dev/null
EXIT_CODE=$?

# Kill the killer process if it's still running
kill $KILLERpid 2>/dev/null

if [ $EXIT_CODE -eq 0 ]; then
    echo "⚠️  Server exited immediately (exit 0)"
    echo "   This might be okay if it processed the request"
elif [ $EXIT_CODE -eq 143 ] || [ $EXIT_CODE -eq 15 ]; then
    echo "✅ Server stayed alive and was killed by timeout"
    echo "   This means the process didn't die - good sign!"
else
    echo "❌ Server crashed (exit $EXIT_CODE)"
fi

echo ""
echo "Things to check:"
echo "1. Is Node.js properly installed at v24.8.0?"
echo "2. Run: node $SERVER_PATH --help"
echo "3. Check: npm list in protokoll directory"
echo "4. Look for error messages in Xcode console"
