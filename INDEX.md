# Protokoll macOS - Complete Index

A complete native macOS application for Protokoll audio transcription.

## 📁 Project Structure

```
protokoll-osx/
│
├── 📦 Build Configuration
│   ├── Package.swift              Swift Package Manager config
│   ├── .gitignore                 Git ignore rules
│   └── run.sh                     Convenience build & run script
│
├── 📚 Documentation (7 files)
│   ├── README.md                  Main documentation & overview
│   ├── QUICKSTART.md              Getting started guide
│   ├── OVERVIEW.md                Technical deep dive
│   ├── DESIGN.md                  Design philosophy & patterns
│   ├── SCREENS.md                 ASCII art UI mockups
│   ├── SUMMARY.md                 What was built & why
│   ├── NEXT_STEPS.md              Roadmap & future enhancements
│   └── INDEX.md                   This file
│
├── 💻 Source Code (9 files, ~1,500 lines)
│   └── Sources/
│       ├── ProtokolApp.swift          App entry, window, menu commands
│       ├── AppState.swift              State management & data models
│       ├── ContentView.swift           Main navigation structure
│       ├── TranscribeView.swift        Drag-and-drop processing UI
│       ├── TranscriptsView.swift       Transcript browser & viewer
│       ├── ContextView.swift           Knowledge base visualization
│       ├── ActivityView.swift          Statistics dashboard
│       ├── SettingsView.swift          Configuration panels
│       └── ProtokolService.swift       CLI integration layer
│
└── ⚖️ Legal
    └── LICENSE                     Apache 2.0
```

## 📖 Documentation Guide

### Start Here
**README.md** - If you're new, start here. Explains what this is, how to install, and basic usage.

### Quick Start
**QUICKSTART.md** - Step-by-step guide to get the app running in 5 minutes. Perfect for first-time users.

### Understanding the Code
**OVERVIEW.md** - Technical overview of the architecture, data flow, and how everything fits together.

### Design Decisions
**DESIGN.md** - Why things look and work the way they do. Design principles, color palette, typography.

### Visual Preview
**SCREENS.md** - ASCII art representations of each screen. See what the app looks like before running it.

### What You Got
**SUMMARY.md** - Complete summary of features, stats, and what makes this special.

### What's Next
**NEXT_STEPS.md** - Ideas for customization, advanced features, distribution, and learning resources.

### This File
**INDEX.md** - Navigation guide to all files and documentation.

## 🎯 Use Cases & Where to Look

### "I want to run the app now"
→ **QUICKSTART.md** section "Running the App"
→ Or just run: `./run.sh`

### "I want to understand how it works"
→ **OVERVIEW.md** section "How It Works"
→ Then read **Sources/ProtokolService.swift** (CLI integration)

### "I want to customize the UI"
→ **DESIGN.md** for design principles
→ **SCREENS.md** to see layouts
→ Edit **Sources/*View.swift** files

### "I want to add features"
→ **NEXT_STEPS.md** section "Medium Term" and "Long Term"
→ Look at **Sources/AppState.swift** for data models
→ Add views in **Sources/**

### "I want to change settings"
→ **Sources/SettingsView.swift** - UI
→ **Sources/AppState.swift** - ProtokolSettings struct

### "I want to fix the YAML parsing"
→ **Sources/ProtokolService.swift** - loadPerson() and loadProject()
→ **NEXT_STEPS.md** section "Better YAML Parsing"

### "I want to distribute the app"
→ **NEXT_STEPS.md** section "Distribution Options"
→ **README.md** section "Building for Distribution"

## 🗺️ Source Code Map

### Core Application
```
ProtokolApp.swift
├── WindowGroup (main window)
├── Settings (preferences window)
└── Commands (keyboard shortcuts)
```

### State Management
```
AppState.swift
├── @Published properties (reactive state)
├── Data models (Transcript, Person, Project, etc.)
└── Enums (ProcessingFile.Status, MainTab)
```

### Navigation
```
ContentView.swift
├── Sidebar (tab navigation)
└── DetailView (tab content)
    ├── TranscribeView
    ├── TranscriptsView
    ├── ContextView
    └── ActivityView
```

### Views Hierarchy
```
TranscribeView
├── Drop zone
├── File picker
└── ProcessingQueueView
    └── ProcessingFileRow (per file)

TranscriptsView
├── Search bar
├── Sort picker
├── List
│   └── TranscriptRow (per transcript)
└── Detail pane
    └── TranscriptDetailView

ContextView
├── Category picker (segmented control)
└── Lists
    ├── PeopleListView
    ├── ProjectsListView
    ├── CompaniesListView
    └── TermsListView

ActivityView
├── Stat cards (grid)
├── Recent activity (list)
└── Context knowledge (grid)

SettingsView (TabView)
├── GeneralSettingsView
├── PathsSettingsView
├── ModelsSettingsView
└── AdvancedSettingsView
```

### Service Layer
```
ProtokolService.swift
├── processAudioFile() → spawns CLI process
├── loadGeneratedTranscript() → parses output
├── loadContext() → reads YAML files
├── loadPerson() → parse person YAML
└── loadProject() → parse project YAML
```

## 📊 Statistics

### Code
- **Total Lines**: ~1,500
- **Swift Files**: 9
- **Average per file**: ~165 lines
- **Largest file**: TranscriptsView.swift (~280 lines)
- **Smallest file**: ContentView.swift (~50 lines)

### Documentation
- **Doc files**: 7
- **Total words**: ~15,000
- **README**: 2,500 words
- **Complete**: Covers all aspects

### Features
- **Main views**: 4 (Transcribe, Transcripts, Context, Activity)
- **Settings tabs**: 4 (General, Paths, Models, Advanced)
- **Data models**: 8 structs
- **Custom components**: 15+ views

## 🔑 Key Files Deep Dive

### ProtokolApp.swift
**Purpose**: Application entry point
**Key Features**:
- Window configuration (min size 1000×700)
- Keyboard shortcuts (⌘+O for open files)
- Settings window integration
- Environment object setup

**Important code**:
```swift
@main
struct ProtokolApp: App
```

### AppState.swift
**Purpose**: Central state management
**Key Features**:
- Observable object for reactive UI
- All data models (Transcript, Person, Project, etc.)
- Processing file queue
- Settings configuration

**Important code**:
```swift
class AppState: ObservableObject {
    @Published var processingFiles: [ProcessingFile]
    @Published var transcripts: [Transcript]
    // ...
}
```

### TranscribeView.swift
**Purpose**: Main transcription interface
**Key Features**:
- Drag-and-drop zone
- File picker integration
- Processing queue with real-time status
- Visual feedback (colors, icons, progress)

**Important code**:
```swift
.onDrop(of: [.fileURL], isTargeted: $isDragging)
```

### TranscriptsView.swift
**Purpose**: Browse and view transcripts
**Key Features**:
- Search and filter
- Sort options
- Master-detail layout
- Confidence badges
- "Show in Finder" integration

**Important code**:
```swift
NavigationSplitView {
    // List of transcripts
} detail: {
    // Transcript detail view
}
```

### ContextView.swift
**Purpose**: Visualize learned knowledge
**Key Features**:
- Tabbed interface (People, Projects, Companies, Terms)
- Lists with metadata
- Phonetic variants display
- Reload functionality

**Important code**:
```swift
Picker("Category", selection: $selectedCategory) {
    ForEach(ContextCategory.allCases)
}
.pickerStyle(.segmented)
```

### ActivityView.swift
**Purpose**: Statistics and activity dashboard
**Key Features**:
- Stat cards (total, weekly, confidence)
- Recent activity feed
- Context knowledge summary
- Beautiful grid layouts

**Important code**:
```swift
LazyVGrid(columns: [GridItem(.flexible()), ...])
```

### SettingsView.swift
**Purpose**: Application configuration
**Key Features**:
- Four-tab interface
- API key management
- Path configuration
- Model selection
- Form validation

**Important code**:
```swift
TabView {
    GeneralSettingsView()
        .tabItem { Label("General", systemImage: "gear") }
    // ...
}
```

### ProtokolService.swift
**Purpose**: CLI integration and YAML parsing
**Key Features**:
- Process spawning (execute protokoll CLI)
- Status monitoring
- YAML parsing (simplified)
- Context loading

**Important code**:
```swift
let task = Process()
task.executableURL = URL(fileURLWithPath: "/bin/zsh")
task.arguments = ["-c", "\(settings.protokollPath) ..."]
```

## 🎨 UI Components Catalog

### Cards
- **StatCard**: Large stat with icon and gradient
- **ContextStatCard**: Compact count with icon
- Both in **ActivityView.swift**

### Badges
- **ConfidenceBadge**: Color-coded percentage pill
- In **TranscriptsView.swift**

### Rows
- **ProcessingFileRow**: Queue item with status
- **TranscriptRow**: List item with metadata
- In **TranscribeView.swift** and **TranscriptsView.swift**

### Lists
- **PeopleListView**: People with phonetic variants
- **ProjectsListView**: Projects with routing rules
- **CompaniesListView**: Companies with context
- **TermsListView**: Terms with variants
- All in **ContextView.swift**

### Forms
- **GeneralSettingsView**: API key, toggles
- **PathsSettingsView**: Directory pickers
- **ModelsSettingsView**: Model selection
- All in **SettingsView.swift**

## 🚀 Quick Commands

### Run (Debug)
```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
swift run
```

### Build (Release)
```bash
swift build -c release
.build/release/Protokoll
```

### Run Script
```bash
./run.sh
```

### Clean
```bash
swift package clean
```

### Generate Xcode Project
```bash
swift package generate-xcodeproj
open Protokoll.xcodeproj
```

### Count Lines
```bash
wc -l Sources/*.swift
```

### List Files
```bash
ls -lh Sources/
```

## 🔍 Finding Things

### "Where is X defined?"

| What | Where |
|------|-------|
| Data models | `AppState.swift` |
| Main window | `ProtokolApp.swift` |
| Navigation | `ContentView.swift` |
| Drag-and-drop | `TranscribeView.swift` |
| Search/browse | `TranscriptsView.swift` |
| Context display | `ContextView.swift` |
| Stats dashboard | `ActivityView.swift` |
| Settings UI | `SettingsView.swift` |
| CLI integration | `ProtokolService.swift` |

### "Where do I change X?"

| What | Where |
|------|-------|
| Color scheme | Any `*View.swift`, look for `.foregroundColor()` |
| Window size | `ProtokolApp.swift`, `.frame(minWidth:)` |
| Models list | `SettingsView.swift`, `let reasoningModels` |
| Tab order | `AppState.swift`, `enum MainTab` |
| Shortcuts | `ProtokolApp.swift`, `.commands` |
| YAML parsing | `ProtokolService.swift`, `loadPerson()` |

## 📝 Common Modifications

### Change Primary Color
1. Open any view file
2. Find `.foregroundStyle(.blue.gradient)`
3. Change to `.foregroundStyle(.purple.gradient)` or any color

### Add a New Tab
1. Edit `AppState.swift`, add case to `MainTab` enum
2. Edit `ContentView.swift`, add case to `DetailView` switch
3. Create new view file in `Sources/`
4. Import in `ContentView.swift`

### Add a Model
1. Edit `SettingsView.swift`
2. Find `let reasoningModels`
3. Add your model to the array

### Change Settings
1. Edit `AppState.swift`, add property to `ProtokolSettings`
2. Edit `SettingsView.swift`, add UI control
3. Edit `ProtokolService.swift`, use new setting

## 🎓 Learning Path

### Beginner (Just Use It)
1. Read **QUICKSTART.md**
2. Run `./run.sh`
3. Try transcribing files
4. Explore the interface

### Intermediate (Customize)
1. Read **DESIGN.md**
2. Change colors/fonts
3. Add keyboard shortcuts
4. Tweak layouts

### Advanced (Extend)
1. Read **OVERVIEW.md**
2. Add new features
3. Fix YAML parsing
4. Implement charts

## 🤝 Contributing

If you improve this:
1. Fork the repo
2. Create a branch
3. Make changes
4. Submit PR
5. Help others

## 📄 License

Apache 2.0 - See LICENSE file

## 🙏 Acknowledgments

- **Protokoll CLI**: @redaksjon/protokoll
- **SwiftUI**: Apple
- **Design**: macOS Human Interface Guidelines

---

**This index covers everything you need to know about this project.**

Questions? Start with the relevant doc file above. Still stuck? Read the source code comments. Everything is documented.

Enjoy building! 🚀
