# Protokoll macOS - Quick Start Guide

## What You've Got

A beautiful, native macOS application for Protokoll with:

### ✨ Key Features

**🎙️ Transcribe Tab**
- Drag-and-drop audio files for instant processing
- Beautiful drop zone with visual feedback
- Real-time processing queue showing status for each file
- Support for .m4a, .mp3, .wav, .aiff, .flac

**📝 Transcripts Tab**
- Browse all your transcripts in one place
- Search across titles and content
- Sort by date or title
- View detailed metadata (confidence scores, projects, duration)
- Click to open in Finder

**🧠 Context Tab**
- View all your learned knowledge
- See people, projects, companies, and terms
- Understand phonetic mappings ("pre a" → "Priya")
- Browse routing rules

**📊 Activity Tab**
- Real-time statistics dashboard
- Weekly summary cards
- Confidence tracking
- Context knowledge growth visualization

**⚙️ Settings**
- Configure OpenAI API key
- Set input/output directories
- Choose AI models (GPT-5.2, Claude, etc.)
- Toggle interactive mode, self-reflection, verbose logging

## Running the App

### Option 1: Create and Launch App Bundle (Recommended)

```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
./create-app.sh
open Protokoll.app
```

### Option 2: Double-Click in Finder

After running `./create-app.sh`, you can simply double-click `Protokoll.app` in Finder.

### Option 3: Open in Xcode

```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
open Package.swift
```

Then press ⌘+R to build and run.

## First-Time Setup

1. **Launch the app** using one of the methods above

2. **Open Settings** (⌘+,)

3. **Configure API Key**
   - Go to General tab
   - Enter your OpenAI API key
   - Get one at [platform.openai.com](https://platform.openai.com)

4. **Set Paths** (Paths tab)
   - Input Directory: Where your audio files are (default: ~/Downloads)
   - Output Directory: Where transcripts go (default: ~/notes)
   - Context Directory: Where Protokoll learns (default: ~/.protokoll)
   - Protokoll CLI Path: Path to `protokoll` command

5. **Choose Models** (Models tab)
   - Reasoning Model: gpt-5.2 (recommended) or others
   - Transcription Model: whisper-1 (default)

6. **Save Settings** and close

## Using the App

### Transcribing Audio

1. Click the **Transcribe** tab
2. **Drag audio files** onto the drop zone
   - Or click "Choose Files" to browse
3. Watch the **processing queue**:
   - 🕐 Pending → Waiting to start
   - 🎵 Transcribing → Whisper is processing
   - ✨ Enhancing → AI is cleaning up
   - 🔀 Routing → Finding the right destination
   - ✅ Completed → Done!
4. View results in the **Transcripts** tab

### Managing Transcripts

1. Click the **Transcripts** tab
2. **Search** for keywords in titles or content
3. **Sort** by date or title
4. **Click a transcript** to view details
5. **Show in Finder** button to open the file location

### Exploring Context

1. Click the **Context** tab
2. Choose category:
   - **People**: View all recognized names with phonetic variants
   - **Projects**: See routing rules and trigger phrases
   - **Companies**: Browse organization knowledge
   - **Terms**: Check technical vocabulary
3. Click **Reload** to refresh from disk

### Monitoring Activity

1. Click the **Activity** tab
2. View:
   - Total transcripts processed
   - This week's activity
   - Average confidence scores
   - Recent transcriptions
   - Context knowledge growth

## Architecture

This app is a **native Swift/SwiftUI frontend** that wraps the Protokoll CLI:

```
┌─────────────────────────────────────┐
│   Protokoll macOS (Swift/SwiftUI)   │
├─────────────────────────────────────┤
│  • Beautiful native UI               │
│  • Drag-and-drop processing          │
│  • Real-time status updates          │
│  • Context visualization             │
└──────────────┬──────────────────────┘
               │ Executes CLI commands
               ↓
┌─────────────────────────────────────┐
│      Protokoll CLI (Node.js)         │
├─────────────────────────────────────┤
│  • Audio transcription (Whisper)     │
│  • AI enhancement (GPT/Claude)       │
│  • Context management                │
│  • Smart routing                     │
└─────────────────────────────────────┘
```

## Project Structure

```
Sources/
├── ProtokolApp.swift         # App entry point & window management
├── AppState.swift             # State management & data models
├── ContentView.swift          # Main navigation structure
├── TranscribeView.swift       # Drag-and-drop processing UI
├── TranscriptsView.swift      # Transcript browser & viewer
├── ContextView.swift          # Context knowledge viewer
├── ActivityView.swift         # Stats dashboard
├── SettingsView.swift         # Settings panels
└── ProtokolService.swift      # CLI integration layer
```

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Swift 5.9+**
- **Protokoll with MCP Server** installed:
  ```bash
  npm install -g @redaksjon/protokoll
  # This installs both protokoll CLI and protokoll-mcp server
  ```
- **OpenAI API Key** from [platform.openai.com](https://platform.openai.com)

## What's New: MCP Integration

This app now uses the **Model Context Protocol (MCP)** to communicate with Protokoll:

✅ **Persistent Connection** - No shell spawning overhead
✅ **Structured Data** - JSON-RPC instead of text parsing  
✅ **Resource-Based** - Uses `protokoll://transcripts` resources
✅ **Type-Safe** - Swift Codable for all MCP messages
✅ **Auto-Reconnect** - Handles server crashes gracefully

The app automatically starts a `protokoll-mcp` server process and maintains a connection throughout its lifetime.

## Building for Distribution

### Create App Bundle (Xcode)

```bash
# Generate Xcode project
swift package generate-xcodeproj
open Protokoll.xcodeproj

# In Xcode:
# 1. Product → Archive
# 2. Distribute App → Copy App
# 3. Choose location for .app bundle
```

### Manual Build

```bash
swift build -c release
# Binary at: .build/release/Protokoll
```

## Troubleshooting

### "Command not found: protokoll"

The app can't find the Protokoll CLI. Fix:

1. Install Protokoll: `npm install -g @redaksjon/protokoll`
2. Find path: `which protokoll`
3. Update in Settings → Paths → Protokoll Path

### "Processing failed"

Check:
- OpenAI API key is set correctly
- Audio file format is supported
- Output directory exists and is writable
- Enable verbose logging in Settings

### "No transcripts appearing"

The app monitors the output directory. Make sure:
- Output directory is set correctly in Settings
- Protokoll CLI completed successfully
- Files have .md extension

## What Makes This Special

This isn't just another wrapper around a CLI tool. It's a **thoughtfully designed native macOS experience** that:

- **Feels native**: Uses SwiftUI, system fonts, macOS design patterns
- **Respects your workflow**: No forced cloud, no subscriptions, your data stays local
- **Visualizes learning**: See exactly what Protokoll knows about your world
- **Provides transparency**: Every routing decision includes reasoning and confidence
- **Stays out of your way**: Drag files, get transcripts, done

The CLI is powerful but requires terminal knowledge. This app makes that power accessible with a beautiful, intuitive interface.

## Next Steps

- Try transcribing your first audio file
- Explore the Context tab to see what Protokoll learns
- Set up a project-specific routing rule
- Check the Activity dashboard to track your usage

Enjoy! 🎉
