# Protokoll for macOS - Overview

## What Is This?

A **beautiful, native macOS application** that brings Protokoll's intelligent audio transcription to your desktop with a modern SwiftUI interface.

Instead of typing commands in Terminal, you get:
- 🎯 Drag-and-drop audio processing
- 📊 Real-time processing queues with visual feedback
- 🧠 Context system visualization (see what Protokoll learns)
- 📝 Built-in transcript browser with search
- 📈 Activity dashboard with statistics
- ⚙️ Graphical settings instead of config files

## The Stack

```
┌──────────────────────────────────────────────┐
│        Protokoll.app (Native macOS)          │
│                                              │
│  • Swift 5.9                                 │
│  • SwiftUI (declarative UI)                  │
│  • macOS 14.0+ (Sonoma)                      │
│  • ~1500 lines of code                       │
│                                              │
│  Features:                                   │
│  ✓ Drag-and-drop interface                  │
│  ✓ Real-time status updates                 │
│  ✓ Context visualization                    │
│  ✓ Transcript browser                       │
│  ✓ Activity dashboard                       │
│  ✓ Native settings UI                       │
└──────────────┬───────────────────────────────┘
               │ Shell execution
               ↓
┌──────────────────────────────────────────────┐
│      Protokoll CLI (@redaksjon/protokoll)    │
│                                              │
│  • Node.js/TypeScript                        │
│  • OpenAI Whisper (transcription)            │
│  • GPT/Claude (enhancement)                  │
│  • Context management system                 │
│  • Smart routing                             │
└──────────────────────────────────────────────┘
```

## Project Structure

```
protokoll-osx/
├── Sources/
│   ├── ProtokolApp.swift         # App entry + window setup
│   ├── AppState.swift             # State management + models
│   ├── ContentView.swift          # Main navigation
│   ├── TranscribeView.swift       # Drag-and-drop UI
│   ├── TranscriptsView.swift      # Browser + viewer
│   ├── ContextView.swift          # Knowledge visualization
│   ├── ActivityView.swift         # Stats dashboard
│   ├── SettingsView.swift         # Config UI
│   └── ProtokolService.swift      # CLI integration
│
├── Package.swift                  # Swift PM config
├── README.md                      # Main documentation
├── QUICKSTART.md                  # Getting started guide
├── DESIGN.md                      # Design philosophy
├── OVERVIEW.md                    # This file
├── LICENSE                        # Apache 2.0
├── .gitignore
└── run.sh                         # Convenience script
```

## Key Components

### 1. TranscribeView (The Main Event)
- **Large drop zone** with visual feedback
- **File picker** as alternative to drag-and-drop
- **Processing queue** showing status for each file:
  - ⏳ Pending
  - 🎵 Transcribing
  - ✨ Enhancing
  - 🔀 Routing
  - ✅ Completed / ❌ Failed

### 2. TranscriptsView (Browser)
- **Search bar** for filtering by title or content
- **Sort options** (newest, oldest, A-Z)
- **List view** with metadata (date, duration, confidence)
- **Detail pane** showing full content
- **Show in Finder** button

### 3. ContextView (Knowledge Base)
- **Segmented control** to switch between:
  - People (names + phonetic variants)
  - Projects (routing rules + triggers)
  - Companies (organization knowledge)
  - Terms (vocabulary)
- **Reload button** to refresh from disk

### 4. ActivityView (Dashboard)
- **Stat cards**: Total transcripts, this week, avg confidence
- **Recent activity** feed
- **Context knowledge** summary (counts by type)

### 5. SettingsView (Configuration)
- **General tab**: API key, processing options
- **Paths tab**: Directories, CLI path
- **Models tab**: Choose GPT/Claude models
- **Advanced tab**: Future expansion

## Data Models

### AppState
Central state management object holding:
- `processingFiles`: Queue of files being processed
- `transcripts`: List of completed transcripts
- `settings`: User configuration
- `contextData`: Loaded knowledge (people, projects, etc.)
- `selectedTab`: Current view

### ProtokolSettings
User preferences:
- API keys
- Directory paths
- Model choices
- Feature flags (interactive, verbose, etc.)

### Transcript
Represents a completed transcription:
- Metadata (title, date, project, confidence)
- Content (full text)
- File path (for "Show in Finder")

### ContextData
Knowledge from `.protokoll/`:
- People (names + phonetic variants)
- Projects (routing rules + triggers)
- Companies (organizations)
- Terms (vocabulary)

## How It Works

### Processing Flow

1. **User drops audio file** on TranscribeView
2. **File added to queue** (AppState.processingFiles)
3. **ProtokolService spawns process**:
   ```bash
   protokoll \
     --input-directory /path/to/file \
     --output-directory ~/notes \
     --model gpt-5.2 \
     --transcription-model whisper-1
   ```
4. **Status updates** as CLI progresses
5. **On completion**: Parse output, load transcript
6. **Add to TranscriptsView** for browsing

### Context Loading

1. **User opens Context tab** (or app launches)
2. **ProtokolService scans** `~/.protokoll/`:
   ```
   ~/.protokoll/
   ├── people/*.yaml
   ├── projects/*.yaml
   ├── companies/*.yaml
   └── terms/*.yaml
   ```
3. **Parse YAML** (simplified parser in demo)
4. **Update AppState.contextData**
5. **UI refreshes** with loaded data

## Design Highlights

### Native Feel
- System fonts (SF Pro)
- Platform colors (adapts to light/dark mode)
- Standard controls (buttons, pickers, text fields)
- Keyboard shortcuts (⌘+O, ⌘+,)

### Visual Feedback
- **Color-coded confidence**:
  - 🟢 Green: >85% (high confidence)
  - 🟠 Orange: 70-85% (medium)
  - 🔴 Red: <70% (needs review)
- **Status icons** for each processing stage
- **Progress indicators** while working

### Information Architecture
```
Sidebar Navigation
├── 🎙️ Transcribe     ← Start here (most common action)
├── 📝 Transcripts    ← Browse results
├── 🧠 Context        ← Understand learning
└── 📊 Activity       ← Track usage
```

## Running the App

### Quick Start
```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
swift run
```

### Release Build
```bash
swift build -c release
.build/release/Protokoll
```

### With Run Script
```bash
./run.sh
```

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Xcode 15.0+** (for Swift 5.9)
- **Protokoll CLI** installed:
  ```bash
  npm install -g @redaksjon/protokoll
  ```
- **OpenAI API key** from platform.openai.com

## What Makes It Special

### 1. Truly Native
Not Electron. Not web-wrapped. Pure SwiftUI running on native Apple frameworks.

### 2. Respects Privacy
Your data never leaves your computer. The app just orchestrates the CLI, which you already trust.

### 3. Visual Learning
See exactly what Protokoll knows about your world. Phonetic variants, routing rules, confidence scores—all transparent.

### 4. Zero Configuration Start
Install, set API key, drag files. That's it.

### 5. Scales with You
- Beginner: Just drag files
- Intermediate: Browse context, tweak settings
- Advanced: Understand routing, tune confidence thresholds

## Limitations & Future Work

### Current Limitations
- Simplified YAML parsing (should use proper library)
- No real-time CLI output streaming
- Can't edit context entities from UI (yet)
- No chart visualization (though ActivityView has placeholders)

### Planned Enhancements
- **Timeline view**: See transcriptions over time
- **Inline editing**: Fix transcripts without opening files
- **Context management**: Add/edit people, projects from UI
- **Batch operations**: Combine, export, delete multiple
- **Charts**: Confidence trends, weekly activity
- **Menu bar mode**: Background processing
- **Quick Look**: Preview transcripts without opening

### Nice-to-Haves
- iCloud sync (optional)
- Shortcuts integration
- Share extension (transcribe from Files)
- Export to PDF, DOCX, etc.
- Custom themes
- Team features (shared context)

## Philosophy

This app exists because **great tools deserve great interfaces**.

Protokoll CLI is powerful but requires terminal knowledge. Many users would benefit from it but don't know `--input-directory` from `--transcription-model`.

This app makes that power accessible with:
- **Familiar patterns** (drag-and-drop, not command flags)
- **Visual feedback** (progress bars, not terminal scrollback)
- **Discoverable features** (tabs, not man pages)
- **Native polish** (feels like it belongs on macOS)

## Contributing

Want to improve this? Ideas:

**Easy Wins**
- Better YAML parsing (use SwiftyYAML or similar)
- Add animations (smooth status transitions)
- Improve error messages
- Add unit tests

**Medium**
- Real-time CLI output streaming
- Context entity editor (add/edit/delete)
- Chart visualization (SwiftUI Charts)
- Export functionality

**Advanced**
- Menu bar app mode
- Shortcuts integration
- Share extension
- Multi-window support
- iCloud sync

## License

Apache 2.0 - Same as Protokoll CLI

## Credits

- **Protokoll CLI**: @redaksjon/protokoll by Tim O'Brien
- **macOS App**: Built with SwiftUI
- **Design**: Follows macOS Human Interface Guidelines
- **Icons**: SF Symbols (Apple)

---

Enjoy your beautiful new Protokoll experience! 🎉
