# Protokoll for macOS

A beautiful native macOS application for Protokoll - intelligent audio transcription with context awareness.

## Features

### 🎙️ Audio Transcription
- Drag-and-drop audio files for instant processing
- Real-time processing queue with status updates
- Support for multiple audio formats (.m4a, .mp3, .wav, .aiff, .flac)
- Beautiful progress indicators and completion notifications

### 📝 Transcript Management
- Browse and search all your transcripts
- Rich metadata display (confidence scores, projects, duration)
- Open transcripts in Finder with one click
- Full-text search across all transcripts

### 🧠 Context System
- View and manage people, projects, companies, and terms
- See phonetic variants and sounds-like mappings
- Understand how Protokoll learns your vocabulary
- Browse routing rules and project configurations

### 📊 Activity Dashboard
- Real-time statistics on transcription activity
- Weekly summaries and confidence tracking
- Context knowledge growth visualization
- Recent activity feed

### ⚙️ Settings
- Configure API keys and paths
- Choose AI models for transcription and reasoning
- Set up directory structures
- Customize processing options

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+
- Protokoll CLI installed (`npm install -g @redaksjon/protokoll`)
- OpenAI API key

## Installation

### From Source

1. Clone this repository:
```bash
git clone https://github.com/redaksjon/protokoll-osx.git
cd protokoll-osx
```

2. Create the app bundle:
```bash
./create-app.sh
```

3. Launch the application:
```bash
open Protokoll.app
```

Or simply double-click `Protokoll.app` in Finder.

### Building with Xcode

1. Open the package in Xcode:
```bash
open Package.swift
```

2. Build and run in Xcode (⌘+R)

## Configuration

1. Open Settings (⌘+,)
2. Enter your OpenAI API key in the General tab
3. Configure paths in the Paths tab:
   - Input Directory: Where audio files are located
   - Output Directory: Where transcripts will be saved
   - Context Directory: Where Protokoll stores learned context (~/.protokoll)
4. Choose your preferred AI models in the Models tab

## Usage

### Transcribing Audio

1. Click the "Transcribe" tab
2. Drag audio files onto the drop zone, or click "Choose Files"
3. Watch the processing queue as Protokoll:
   - Transcribes your audio with Whisper
   - Enhances with AI reasoning models
   - Routes to the correct project folder
4. View completed transcripts in the Transcripts tab

### Managing Context

1. Click the "Context" tab
2. Browse people, projects, companies, and terms
3. See how Protokoll maps phonetic variants to correct spellings
4. Understand routing rules for each project

### Viewing Activity

1. Click the "Activity" tab
2. See statistics on your transcription usage
3. Track confidence scores over time
4. Monitor context knowledge growth

## Architecture

This macOS app is a native Swift/SwiftUI frontend that communicates with Protokoll via the Model Context Protocol (MCP). It:

- Provides a beautiful GUI for common Protokoll operations
- **Uses MCP for structured communication** (not shell commands!)
- **Reads transcripts via MCP resources** (`protokoll://transcripts?directory=...`)
- Maintains a persistent connection to the protokoll-mcp server
- Parses YAML context files to display your learned knowledge

### MCP Integration

```
┌─────────────────────────────────────┐
│   Protokoll macOS (Swift/SwiftUI)   │
├─────────────────────────────────────┤
│  • Beautiful native UI               │
│  • MCP Client (Pure Swift)           │
│  • Resource-based data access        │
│  • Real-time status updates          │
└──────────────┬──────────────────────┘
               │ MCP Protocol (JSON-RPC)
               ↓
┌─────────────────────────────────────┐
│      Protokoll MCP Server            │
│      (Node.js - protokoll-mcp)       │
├─────────────────────────────────────┤
│  • Audio transcription (Whisper)     │
│  • AI enhancement (GPT/Claude)       │
│  • Context management                │
│  • Smart routing                     │
└─────────────────────────────────────┘
```

## Development

### Project Structure

```
Sources/
├── ProtokolApp.swift         # Main app entry point
├── AppState.swift             # App state and data models
├── ContentView.swift          # Main navigation structure
├── TranscribeView.swift       # Audio processing interface
├── TranscriptsView.swift      # Transcript browser
├── ContextView.swift          # Context system viewer
├── ActivityView.swift         # Activity dashboard
├── SettingsView.swift         # Settings panels
└── ProtokolService.swift      # Backend service layer
```

### Building for Distribution

To create a distributable app:

```bash
swift build -c release
# The binary will be at .build/release/Protokoll
```

**GitHub Releases (Developer ID + notarization):** see [docs/MACOS_SIGNING_AND_NOTARIZATION.md](docs/MACOS_SIGNING_AND_NOTARIZATION.md) for all Apple/GitHub secret setup steps.

Or build with Xcode for a proper .app bundle:

1. Open project in Xcode
2. Product → Archive
3. Distribute App → Copy App

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

Apache-2.0

## Author

Tim O'Brien <tobrien@discursive.com>

## Related Projects

- [Protokoll CLI](https://github.com/redaksjon/protokoll) - The command-line tool
- [Protokoll MCP Server](https://github.com/redaksjon/protokoll) - MCP integration for AI assistants
