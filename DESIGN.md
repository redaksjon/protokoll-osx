# Design Philosophy

## Native macOS Experience

This app is designed to feel like it belongs on macOS, not like a web app wrapped in Electron.

### Design Principles

**1. Native First**
- Pure SwiftUI components
- System fonts (SF Pro)
- macOS design patterns (NavigationSplitView, Lists, Forms)
- Keyboard shortcuts (⌘+O for open, ⌘+, for settings)
- Native file dialogs and drag-and-drop

**2. Visual Clarity**
- Clear information hierarchy
- Consistent iconography (SF Symbols)
- Meaningful color coding (confidence scores, status indicators)
- Whitespace for breathing room

**3. Progressive Disclosure**
- Start simple (drag-and-drop interface)
- Reveal complexity as needed (settings, advanced features)
- Don't overwhelm new users
- Power features accessible but not intrusive

**4. Feedback & Transparency**
- Real-time processing status
- Clear error messages
- Confidence scores visible
- Reasoning traces available

## Color Palette

**Primary Colors**
- Blue: Primary actions, links, processing
- Green: Success, high confidence (>85%)
- Orange: Warning, medium confidence (70-85%)
- Red: Error, low confidence (<70%)

**Neutrals**
- System grays for secondary text
- Background colors from macOS (respects light/dark mode)

## Typography

**System Fonts (SF Pro)**
- Title: Large, bold for main headings
- Headline: Medium weight for section headers
- Body: Regular for main content
- Caption: Small for metadata

## Layout

**Navigation Structure**
```
┌─────────────────────────────────────────┐
│  [Sidebar]      [Detail View]           │
│  ┌─────────┐   ┌───────────────────┐   │
│  │ Transc. │   │                   │   │
│  │ Transc. │   │   Main Content    │   │
│  │ Context │   │                   │   │
│  │ Activity│   │                   │   │
│  └─────────┘   └───────────────────┘   │
└─────────────────────────────────────────┘
```

**Key Measurements**
- Sidebar: 200pt min width
- Main window: 1000×700pt min size
- Padding: 12-24pt between major sections
- Corner radius: 8-12pt for cards

## Components

### Stat Cards
Large numbers with icons, gradient backgrounds
Use: Activity dashboard

### Confidence Badges
Small percentage pills with color coding
Use: Transcript lists, detail views

### Processing Queue
Stacked rows with icons, progress, and status
Use: Transcribe view during processing

### Context Lists
Hierarchical information with primary/secondary text
Use: Context tab for people, projects, etc.

## Interaction Patterns

**Drag-and-Drop**
- Large, obvious drop zone
- Visual feedback (blue highlight) on hover
- Clear acceptance criteria (supported formats)

**Selection**
- List selection for browsing (transcripts)
- Detail view shows selected item
- Empty state when nothing selected

**Search**
- Real-time filtering as you type
- Clear button when text present
- Shows result count

**Settings**
- Tabbed interface (General, Paths, Models, Advanced)
- Form-based with clear labels
- Validation and helpful error messages

## Voice & Tone

**Messaging Style**
- Friendly but professional
- Clear, concise instructions
- No jargon unless necessary
- Helpful error messages (explain what went wrong and how to fix)

**Examples**
- ✅ "Drag audio files here or choose files"
- ✅ "OpenAI API key required. Get one at platform.openai.com"
- ✅ "Processing failed: Audio file too large (>25MB)"
- ❌ "Error 4012: Invalid configuration parameter"

## Accessibility

- Full VoiceOver support (SwiftUI provides this)
- Keyboard navigation for all features
- Clear focus indicators
- High contrast mode support
- Dynamic type support

## Performance

**Fast & Responsive**
- Async processing (DispatchQueue)
- Non-blocking UI updates
- Background processing for CLI calls
- Efficient list rendering (LazyVGrid, ForEach)

**Resource Conscious**
- Minimal memory footprint
- No unnecessary background processing
- Efficient YAML parsing
- Smart caching where appropriate

## Future Enhancements

Ideas for future versions:

**Features**
- Timeline view of transcriptions
- Charts for confidence trends
- Inline editing of transcripts
- Context entity creation (add people/projects from UI)
- Batch operations (combine, delete, export)
- Quick Look support for transcripts

**Polish**
- Animations for status changes
- Sound effects (subtle, optional)
- Menu bar app mode (background processing)
- Today widget (recent transcripts)
- Share extension (transcribe from Files app)

**Advanced**
- Multi-window support
- Cloud sync (optional)
- Team collaboration features
- Custom themes
- Export presets (PDF, Markdown variants)

## Technical Decisions

**Why Swift Package Manager over Xcode project?**
- Simpler project structure
- Version control friendly
- Easier to understand and modify
- Generate Xcode project when needed

**Why SwiftUI over AppKit?**
- Modern, declarative UI
- Less boilerplate
- Better maintainability
- Automatic dark mode support
- Future-proof

**Why wrap CLI instead of reimplementing?**
- Avoid duplication
- Leverage battle-tested logic
- Easy to update when CLI improves
- Focus on what makes native app valuable (UI/UX)

**Trade-offs**
- Requires Protokoll CLI installed (acceptable)
- Some features harder to access (acceptable)
- Can't easily show real-time CLI output (mitigated with status updates)
