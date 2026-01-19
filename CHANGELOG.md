# Changelog

## [Unreleased] - 2026-01-19

### Added - MCP Integration 🎉

**Major architectural improvement:** The app now uses the Model Context Protocol (MCP) instead of shell commands!

#### New MCP Infrastructure
- Pure Swift MCP client implementation with Swift actors
- Stdio transport for local protokoll-mcp server communication
- JSON-RPC 2.0 message handling
- Resource-based data access (`protokoll://transcripts?directory=...`)
- Automatic server lifecycle management
- Health monitoring and crash recovery

#### Updated Components
- **TranscriptsView**: Now loads transcripts via MCP resources
- **AppState**: Integrated MCP client with automatic initialization
- **Transcript Model**: Extended with MCP-specific fields (filename, time, hasRawTranscript)

#### Default Configuration
- MCP server path: `~/.nvm/versions/node/v24.8.0/bin/protokoll-mcp`
- Output directory: Points to `individual` project in Google Drive
- Context directory: Points to `.protokoll` in individual project

### Benefits

✅ **Performance**: Persistent connection eliminates shell spawning overhead  
✅ **Reliability**: Automatic reconnection and health monitoring  
✅ **Type Safety**: Structured JSON requests/responses  
✅ **Standards**: Uses MCP resources correctly (not tools for reads)  
✅ **Future-Ready**: Can add subscriptions, prompts, more resources

### Technical Details

- **Total Lines**: ~1,200 lines of Swift
- **Files Created**: 14 new files
- **Files Modified**: 2 existing files
- **Build Status**: ✅ Success
- **Architecture**: Resources for reads, Tools for writes (MCP best practice)

### Implementation Notes

Follows the execution plan at `/Users/tobrien/gitw/redaksjon/plans/protokoll-osx-mcp/`:
- Phase 0: Foundation (types, client, transport)
- Phase 1: Server lifecycle
- Phase 2: MCP communication  
- Phase 3: Transcript listing integration

See `MCP_INTEGRATION_TEST.md` and `TESTING.md` for testing instructions.

---

## [Previous Versions]

Initial prototype with shell-based CLI integration.
