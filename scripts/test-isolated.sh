#!/bin/bash
# Run problematic test suites in isolation to avoid hanging
# Usage: ./scripts/test-isolated.sh [ServerManagerTests|StdioTransportTests|both]

set -e

TEST_SUITE="${1:-both}"

echo "🧪 Running isolated tests: $TEST_SUITE"

# Temporarily enable the disabled test files
if [ "$TEST_SUITE" = "ServerManagerTests" ] || [ "$TEST_SUITE" = "both" ]; then
    echo "📦 Enabling ServerManagerTests..."
    mv Tests/ProtokolTests/ServerManagerTests.swift.disabled Tests/ProtokolTests/ServerManagerTests.swift 2>/dev/null || true
fi

if [ "$TEST_SUITE" = "StdioTransportTests" ] || [ "$TEST_SUITE" = "both" ]; then
    echo "📦 Enabling StdioTransportTests..."
    mv Tests/ProtokolTests/StdioTransportTests.swift.disabled Tests/ProtokolTests/StdioTransportTests.swift 2>/dev/null || true
fi

# Clean up any existing build artifacts
swift package clean 2>/dev/null || true

# Run only the specified test suite(s) in isolation
if [ "$TEST_SUITE" = "ServerManagerTests" ]; then
    echo "▶️  Running ServerManagerTests..."
    swift test --filter ProtokolTests.ServerManagerTests
elif [ "$TEST_SUITE" = "StdioTransportTests" ]; then
    echo "▶️  Running StdioTransportTests..."
    swift test --filter ProtokolTests.StdioTransportTests
elif [ "$TEST_SUITE" = "both" ]; then
    echo "▶️  Running ServerManagerTests..."
    swift test --filter ProtokolTests.ServerManagerTests
    echo ""
    echo "▶️  Running StdioTransportTests..."
    swift test --filter ProtokolTests.StdioTransportTests
fi

# Disable them again
if [ "$TEST_SUITE" = "ServerManagerTests" ] || [ "$TEST_SUITE" = "both" ]; then
    mv Tests/ProtokolTests/ServerManagerTests.swift Tests/ProtokolTests/ServerManagerTests.swift.disabled 2>/dev/null || true
fi

if [ "$TEST_SUITE" = "StdioTransportTests" ] || [ "$TEST_SUITE" = "both" ]; then
    mv Tests/ProtokolTests/StdioTransportTests.swift Tests/ProtokolTests/StdioTransportTests.swift.disabled 2>/dev/null || true
fi

echo "✅ Isolated tests completed"
