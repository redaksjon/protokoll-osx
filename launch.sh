#!/bin/bash
# Launch Protokoll macOS app

cd "$(dirname "$0")"

echo "🔨 Building Protokoll..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "🚀 Launching Protokoll..."
    
    # Run the app in the background and detach from terminal
    .build/release/Protokoll &
    
    # Give it a moment to launch
    sleep 1
    
    echo ""
    echo "✨ Protokoll should now be running!"
    echo "   Check your dock or use Cmd+Tab to find it"
    echo ""
    echo "   If you don't see a window, the app may have launched"
    echo "   but encountered an issue. Check Console.app for errors."
    echo ""
else
    echo "❌ Build failed. Please check the errors above."
    exit 1
fi
