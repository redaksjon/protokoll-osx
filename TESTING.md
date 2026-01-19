# Quick Start: Testing MCP Integration

## Launch and Test

### Option 1: Create App Bundle (Recommended)
```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
./create-app.sh
open Protokoll.app
```

### Option 2: Launch Script
```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
./launch.sh
# Builds and launches app in background
```

### Option 3: Xcode (Best for Debugging)
```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
open Package.swift
# Then press ⌘+R to build and run
# Console logs will appear in Xcode's debug area
```

## What Should Happen

1. **App launches** - Window appears with sidebar navigation
2. **MCP initializes** - Check console for:
   ```
   [com.protokoll.app:appstate] Initializing MCP client
   [com.protokoll.mcp:server] Starting server
   [com.protokoll.mcp:client] MCP initialized with server: protokoll v...
   ```

3. **Click Transcripts tab** - Should see:
   - Loading indicator (briefly)
   - List of transcripts from your individual project
   - Count showing total transcripts
   - Search box and pagination controls

4. **Success indicators:**
   - Transcripts appear in the list
   - Each shows: title, date, confidence badge
   - Click a transcript to view details
   - Search works
   - Pagination works (if >50 transcripts)

## If It Doesn't Work

### Check 1: MCP Server Path
The app looks for protokoll-mcp at:
```
/Users/tobrien/.nvm/versions/node/v24.8.0/bin/protokoll-mcp
```

If your path is different:
```bash
which protokoll-mcp  # Find your path
```

Then update `Sources/AppState.swift`:
```swift
var mcpServerPath: String = "YOUR_PATH_HERE"
```

### Check 2: Directory Paths
The app defaults to:
```
Output: /Users/tobrien/Library/CloudStorage/GoogleDrive-tobrien@discursive.com/My Drive/individual
Context: /Users/tobrien/Library/CloudStorage/GoogleDrive-tobrien@discursive.com/My Drive/individual/.protokoll
```

Verify these exist:
```bash
ls "/Users/tobrien/Library/CloudStorage/GoogleDrive-tobrien@discursive.com/My Drive/individual"
```

### Check 3: Console Logs
Look for errors in Console.app:
1. Open Console.app
2. Search for "Protokoll" or "com.protokoll.mcp"
3. Look for error messages

Common errors:
- "Server not found at: ..." - Wrong server path
- "No .protokoll configuration found" - Wrong context directory
- "Process failed to start" - Server not executable

### Check 4: Test MCP Server Manually
```bash
# Test the server works
protokoll-mcp

# Should wait for input. Test with:
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | protokoll-mcp

# Should return JSON with server info
```

## Understanding the Architecture

When you click the Transcripts tab, here's what happens:

1. **TranscriptsView.loadTranscripts()** calls:
   ```swift
   await client.listTranscriptsResource(directory: dir, limit: 50)
   ```

2. **MCPClient** sends JSON-RPC request:
   ```json
   {
     "jsonrpc": "2.0",
     "id": 2,
     "method": "resources/read",
     "params": {
       "uri": "protokoll://transcripts?directory=...&limit=50"
     }
   }
   ```

3. **protokoll-mcp server** processes and returns:
   ```json
   {
     "jsonrpc": "2.0",
     "id": 2,
     "result": {
       "contents": [{
         "uri": "protokoll://transcripts?directory=...",
         "text": "{\"directory\":\"...\",\"transcripts\":[...],\"total\":42}"
       }]
     }
   }
   ```

4. **MCPClient** decodes to `TranscriptsListResource`

5. **TranscriptsView** displays the data

## Success Criteria

✅ **Initial Goal Achieved** if:
- App launches
- MCP client connects
- Transcripts load via MCP resource
- Data from individual project displays
- No crashes or errors

## Next Steps After Testing

Once manual testing confirms it works:
1. Polish error handling
2. Add connection status indicator
3. Update user documentation
4. Consider adding more MCP features (context view, etc.)

---

**Built**: 2026-01-19
**Lines of Code**: ~1,200 lines of Swift
**Phases Complete**: 0-3 (Foundation through UI Integration)
