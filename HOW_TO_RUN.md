# How to Run Protokoll macOS App

## The Right Way to Launch

GUI apps built with SwiftUI need to be run as proper app bundles or through Xcode. **`swift run` doesn't work** for GUI apps.

## Method 1: Create App Bundle (Recommended)

```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
./create-app.sh
open Protokoll.app
```

**What this does:**
1. Builds the app in release mode
2. Creates `Protokoll.app` bundle with proper Info.plist
3. Opens the app

**Benefits:**
- ✅ Proper macOS app
- ✅ Can be moved to Applications folder
- ✅ Can be double-clicked in Finder
- ✅ Works like any other Mac app

## Method 2: Launch Script

```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
./launch.sh
```

**What this does:**
1. Builds in release mode
2. Runs the executable in background
3. Detaches from terminal

**Use this when:**
- Quick testing
- Don't need app bundle
- Console access not needed

## Method 3: Xcode (Best for Development)

```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
open Package.swift
```

Then in Xcode:
1. Wait for indexing to complete
2. Press **⌘+R** to build and run
3. Console logs appear in debug area

**Benefits:**
- ✅ Full debugging support
- ✅ See console logs in real-time
- ✅ Breakpoints work
- ✅ Inspector for UI debugging
- ✅ Best for development

## Why NOT `swift run`?

The error you saw:
```
Connection Invalid error for service com.apple.hiservices-xpcservice
Error received in message reply handler: Connection invalid
```

This happens because `swift run` tries to run a GUI app from the terminal without proper entitlements or windowing system access. SwiftUI apps need to run as proper app bundles.

## Recommended Testing Flow

### First Time Testing
```bash
open Package.swift
# Press ⌘+R in Xcode
# Watch console logs for MCP initialization
# Click Transcripts tab
# Verify transcripts load
```

### Subsequent Testing
```bash
./create-app.sh && open Protokoll.app
# Or just: open Protokoll.app (if already created)
```

### Production Use
```bash
./create-app.sh
# Move Protokoll.app to /Applications/
# Launch from Spotlight or Dock
```

## Verifying It Works

After launching (any method), you should see:

1. **Window appears** with sidebar showing: Transcribe, Transcripts, Context, Activity
2. **Click Transcripts tab**
3. **Loading indicator** appears briefly
4. **Transcripts list** appears with data from individual project

### Check Console Logs

**In Xcode:** Debug area shows logs  
**With App Bundle:** Open Console.app, filter for "Protokoll" or "com.protokoll.mcp"

Look for:
```
[com.protokoll.app:appstate] Initializing MCP client
[com.protokoll.mcp:server] Starting server
[com.protokoll.mcp:transport] Server process started
[com.protokoll.mcp:client] MCP initialized with server: protokoll
[com.protokoll.app:transcripts] Loading transcripts from: ...
[com.protokoll.app:transcripts] Loaded X transcripts
```

## Connecting to a remote MCP server

By default the app runs the **protokoll-mcp** Node server as a subprocess (stdio). To use a **remote** MCP server (e.g. one already running at `http://localhost:3001/mcp`):

1. Start your MCP server (e.g. `./scripts/start-protokoll-mcp.sh` in your activity directory).
2. In the app: **Settings → Advanced**.
3. Set **Remote MCP URL** to `http://localhost:3001/mcp` (or your server’s URL).
4. Restart the app (or reconnect). The app will connect via HTTP/SSE instead of launching the Node process.

Leave **Remote MCP URL** empty to keep the default stdio (subprocess) behavior.

## Debugging MCP

- **In-app log:** **Settings → Advanced** → scroll to **MCP debug log**. This shows a rolling log of each request/response (e.g. `→ initialize id:1`, `← initialize id:1 ok`). Use **Clear** to reset. Handy for seeing if the server is reached and what failed.
- **Console.app:** For transport-level detail (SSE connection, POST URL, session id, bytes), open **Console.app**, filter by `com.protokoll.mcp` or subsystem `Protokoll`, and watch while you use the app or click Reconnect.

## Troubleshooting

### App doesn't launch
```bash
# Check build succeeded
swift build
# Should say: "Build complete!"

# Check executable exists
ls -l .build/debug/Protokoll
```

### Window appears but crashes immediately
- Open Console.app
- Look for Protokoll crash logs
- Check for missing dependencies

### App launches but transcripts don't load
- Verify protokoll-mcp is installed: `which protokoll-mcp`
- Check the path in `Sources/AppState.swift`
- Look at console logs for MCP errors

## Summary

✅ **Use:** `./create-app.sh && open Protokoll.app`  
✅ **Or:** Xcode (⌘+R)  
❌ **Don't use:** `swift run` (doesn't work for GUI apps)

---

**Ready to test?** Run `./create-app.sh` now! 🚀
