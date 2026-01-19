# Debug: MCP Server Not Starting

## Issue

The protokoll-mcp server process starts but immediately dies with SIGPIPE (signal 13).

## What We've Tried

1. ✅ Running through `/usr/bin/env node` - still dies
2. ✅ Running directly with shebang - still dies  
3. ✅ Passing full environment - still dies
4. ✅ Adding startup delay check - still dies

## What Happens

```
Server process started (PID: 56161)
Sending request: initialize (id: 1)
Stdout reading stopped
Terminated due to signal 13 (SIGPIPE)
```

The server process exits immediately, before it can receive/respond to the initialize message.

## Test: Does Server Work Manually?

```bash
# Test 1: Echo to server
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | /Users/tobrien/.nvm/versions/node/v24.8.0/bin/protokoll-mcp

# Should output JSON response
```

## Possible Causes

1. **Missing dependencies**: Server can't find node modules
2. **Missing environment**: OPENAI_API_KEY or other vars not set
3. **Import/module issue**: ESM modules not loading
4. **Permission issue**: Can't access something it needs
5. **Timing issue**: Server exits if no input received immediately

## Next Debug Step

Run in Xcode (⌘+R) and look for **stderr messages** from the server. The updated code now captures stderr before stdout, so we should see any error messages from the server.

Look for lines like:
```
[com.protokoll.mcp:transport] Server stderr: <error message>
```

This will tell us WHY the server is dying.

## Workaround Option

If we can't get the stdio transport working, we could:
1. Start the server separately in a terminal
2. Use HTTP transport instead of stdio
3. Or fall back to shell commands (defeats the purpose but would work)

But let's debug the stderr output first!
