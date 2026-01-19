#!/bin/bash
# Run the Protokoll macOS application

cd "$(dirname "$0")"

echo "Building Protokoll for macOS..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "Build successful! Launching Protokoll..."
    .build/release/Protokoll
else
    echo "Build failed. Please check the errors above."
    exit 1
fi
