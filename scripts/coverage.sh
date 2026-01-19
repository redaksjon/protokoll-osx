#!/bin/bash
# Generate test coverage report in lcov format
# Usage: ./scripts/coverage.sh

set -e

echo "🧪 Running tests with coverage..."
swift test --enable-code-coverage --parallel

echo ""
echo "📊 Generating coverage report..."

# Create coverage directory
mkdir -p coverage

# Find the profdata file
PROFDATA=$(find .build -name "default.profdata" -type f 2>/dev/null | head -1)
if [ -z "$PROFDATA" ]; then
    PROFDATA=$(find .build -name "*.profdata" -type f 2>/dev/null | head -1)
fi

if [ -z "$PROFDATA" ]; then
    echo "❌ No profdata file found. Tests may have failed."
    exit 1
fi

echo "Found profdata: $PROFDATA"

# Find the test binary or library
# On macOS, the test executable is inside an xctest bundle
TEST_BUNDLE=$(find .build -name "*.xctest" -type d 2>/dev/null | head -1)
if [ -n "$TEST_BUNDLE" ]; then
    BINARY="$TEST_BUNDLE/Contents/MacOS/$(basename "$TEST_BUNDLE" .xctest)"
else
    # Fall back to finding any debug executable
    BINARY=$(find .build/debug -type f -perm +111 ! -name "*.dylib" ! -name "*.o" -name "Protokoll*" 2>/dev/null | head -1)
fi

if [ -z "$BINARY" ] || [ ! -f "$BINARY" ]; then
    echo "❌ No test binary found"
    exit 1
fi

echo "Using binary: $BINARY"

# Generate lcov format
echo ""
echo "Generating lcov.info..."
xcrun llvm-cov export \
    -format=lcov \
    -instr-profile="$PROFDATA" \
    "$BINARY" \
    -ignore-filename-regex=".build|Tests" \
    > coverage/lcov.info

# Generate text report
echo ""
echo "📈 Coverage Summary:"
echo "===================="
xcrun llvm-cov report \
    -instr-profile="$PROFDATA" \
    "$BINARY" \
    -ignore-filename-regex=".build|Tests"

# Generate HTML report (optional)
echo ""
echo "Generating HTML report..."
xcrun llvm-cov show \
    -format=html \
    -instr-profile="$PROFDATA" \
    "$BINARY" \
    -ignore-filename-regex=".build|Tests" \
    -output-dir=coverage/html 2>/dev/null || echo "HTML generation skipped"

echo ""
echo "✅ Coverage reports generated:"
echo "   - coverage/lcov.info (for CI/tooling)"
if [ -d "coverage/html" ]; then
    echo "   - coverage/html/index.html (open in browser)"
fi
echo ""
echo "To view HTML report: open coverage/html/index.html"
