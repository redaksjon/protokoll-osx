# Next Steps: After MCP Integration

## Immediate: Manual Testing

The core MCP integration is **ready for testing**! Here's how to verify it works:

### Test Procedure

1. **Launch the app:**
   ```bash
   cd /Users/tobrien/gitw/redaksjon/protokoll-osx
   ./create-app.sh
   open Protokoll.app
   ```
   
   Or use Xcode for better debugging:
   ```bash
   open Package.swift
   # Press ⌘+R in Xcode
   ```

2. **Check console logs** for MCP initialization:
   - Look for "Initializing MCP client"
   - Look for "Server process started"
   - Look for "MCP client initialized successfully"

3. **Navigate to Transcripts tab** and verify:
   - Loading indicator appears
   - Transcripts load from individual project
   - Count shows total number
   - Search works
   - Pagination appears (if >50 transcripts)

4. **Test functionality:**
   - Click a transcript → detail view opens
   - Search for keywords → results filter
   - Click pagination → next page loads

### If It Works ✅

Congratulations! The MCP integration is successful. You now have:
- Faster transcript loading (persistent connection)
- Type-safe communication
- Resource-based architecture
- Foundation for future features

### If It Doesn't Work ⚠️

Check these common issues:

1. **Server path wrong:** Edit `Sources/AppState.swift` line with `mcpServerPath`
2. **Directory paths wrong:** Check `outputDirectory` in `Sources/AppState.swift`
3. **Server won't start:** Run `protokoll-mcp` manually to test
4. **No transcripts found:** Verify the individual directory has transcripts

See `TESTING.md` for detailed troubleshooting.

## Short Term: Polish (Phase 4)

Once manual testing confirms it works, add polish:

### Error Handling Enhancement
```swift
// Add user-friendly error messages
struct ErrorMessages {
    static func userFriendly(for error: Error) -> String {
        // Convert technical errors to user-friendly messages
    }
}
```

### Connection Status Indicator
```swift
// Add to ContentView toolbar
struct MCPStatusBadge: View {
    // Shows green/red indicator for connection status
}
```

### Retry Logic
```swift
// Add automatic retry for transient failures
struct RetryHelper {
    static func withRetry<T>(...) async throws -> T {
        // Retry with exponential backoff
    }
}
```

## Medium Term: Expand MCP Usage

Once transcript listing is solid, expand to other features:

### 1. Context View via Resources
```swift
// Replace YAML file parsing with MCP resources
await client.listEntitiesResource(type: "person")
await client.listEntitiesResource(type: "project")
await client.readResource("protokoll://entity/person/john-smith")
```

### 2. Audio Processing via Tools
```swift
// Use MCP tools for transcription
await client.callTool("protokoll_discover_config", ...)
await client.callTool("protokoll_suggest_project", ...)
await client.callTool("protokoll_process_audio", ...)
```

### 3. Prompt-Based Workflows
```swift
// Use MCP prompts for guided workflows
let messages = await client.getPrompt("transcribe_with_context", ...)
// Render prompt messages in UI
// Guide user through multi-step process
```

## Long Term: Advanced Features

### Resource Subscriptions
```swift
// Subscribe to transcripts directory for live updates
await client.subscribe("protokoll://transcripts?directory=...")
// Receive notifications when new transcripts added
// Auto-refresh UI
```

### Remote Server Support
```swift
// Add HTTP transport for remote servers
let httpTransport = HTTPTransport(url: "https://team-server.com/mcp")
let client = MCPClient(transport: httpTransport)
// Connect to team's Protokoll server
```

### Multi-Context Support
```swift
// Switch between different Protokoll contexts
let personalContext = await client.getConfigResource()
let workContext = await client.getConfigResource(contextDir: "~/work/.protokoll")
// User picks which context to use
```

## Development Priorities

### Priority 1: Verify Core Works
- [ ] Manual testing successful
- [ ] No crashes or errors
- [ ] Transcripts load correctly
- [ ] Performance acceptable

### Priority 2: Polish Existing
- [ ] Better error messages
- [ ] Connection status indicator
- [ ] Retry logic
- [ ] Loading states

### Priority 3: Expand Features
- [ ] Context view via resources
- [ ] Audio processing via tools
- [ ] Settings for MCP configuration

### Priority 4: Advanced
- [ ] Prompt-based workflows
- [ ] Resource subscriptions
- [ ] Remote server support

## Success Criteria

The MCP integration will be considered **production-ready** when:

✅ Core implementation complete (DONE!)  
⬜ Manual testing passes  
⬜ Error handling polished  
⬜ User documentation complete  
⬜ No crashes after 1 hour of use  
⬜ Performance meets expectations  

## Timeline Estimate

- **Today**: Manual testing and bug fixes (2-4 hours)
- **This Week**: Polish and error handling (4-6 hours)
- **Next Week**: Expand to context view (6-8 hours)
- **This Month**: Full MCP feature parity (20-30 hours)

---

**Current Status:** Core complete, ready for testing! 🎉

See `TESTING.md` to get started, or run `swift run` to launch the app now.
