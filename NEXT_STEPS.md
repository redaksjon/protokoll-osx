# What to Do Next 🚀

You've got a complete, working macOS application for Protokoll. Here's your roadmap.

## Immediate: Try It Out (5 minutes)

### 1. Run the App
```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
swift run
```

### 2. Configure Settings
- Press `⌘+,` to open Settings
- Go to **General** tab
- Enter your OpenAI API key
- Go to **Paths** tab
- Set your input/output directories
- Click **Save Settings**

### 3. Test Transcription
- Click the **Transcribe** tab
- Drag an audio file onto the drop zone
- Watch the processing queue
- Check the **Transcripts** tab for results

### 4. Explore Context
- Click the **Context** tab
- See what Protokoll knows
- Browse people, projects, companies, terms

### 5. Check Activity
- Click the **Activity** tab
- View your stats
- See recent transcriptions

## Short Term: Build for Distribution (30 minutes)

### Option 1: Release Build
```bash
swift build -c release
cp .build/release/Protokoll ~/Desktop/
```

Now you have a standalone binary on your Desktop.

### Option 2: Create Xcode Project
```bash
swift package generate-xcodeproj
open Protokoll.xcodeproj
```

In Xcode:
1. Select the Protokoll target
2. Go to Signing & Capabilities
3. Add your Apple Developer team
4. Product → Archive
5. Distribute App → Copy App
6. You get a proper .app bundle

### Option 3: Use the Run Script
```bash
./run.sh
```

This builds in release mode and launches.

## Medium Term: Customization (1-2 hours)

### Easy Customizations

**Change Colors**
Edit `Sources/ActivityView.swift`, `Sources/TranscriptsView.swift`:
```swift
// Find lines like:
.foregroundStyle(.blue.gradient)

// Change to:
.foregroundStyle(.purple.gradient)
```

**Add More Models**
Edit `Sources/SettingsView.swift`:
```swift
let reasoningModels = [
    "gpt-5.2", "gpt-5.1", "gpt-5",
    "gpt-4o", "gpt-4o-mini",
    "claude-3-5-sonnet", "claude-3-opus",
    "your-new-model-here"  // Add here
]
```

**Change Window Size**
Edit `Sources/ProtokolApp.swift`:
```swift
.frame(minWidth: 1000, minHeight: 700)  // Change these
```

**Add Keyboard Shortcuts**
Edit `Sources/ProtokolApp.swift`:
```swift
.commands {
    CommandGroup(replacing: .newItem) {
        Button("Process Audio Files...") {
            appState.showFilePicker = true
        }
        .keyboardShortcut("o", modifiers: .command)
        
        // Add more here
        Button("View Context") {
            appState.selectedTab = .context
        }
        .keyboardShortcut("k", modifiers: .command)
    }
}
```

### Medium Customizations

**Better YAML Parsing**
Replace the simplified parser in `ProtokolService.swift` with a proper library:
```swift
// Add to Package.swift:
.package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")

// Then use Yams instead of manual parsing
```

**Add Animations**
Edit any view file:
```swift
.onChange(of: file.status) { oldStatus, newStatus in
    withAnimation(.spring()) {
        // Update UI with animation
    }
}
```

**Add Charts**
Import Charts framework:
```swift
import Charts

// Add to ActivityView:
Chart {
    ForEach(transcriptsByDay) { day in
        BarMark(
            x: .value("Day", day.date),
            y: .value("Count", day.count)
        )
    }
}
```

## Long Term: Advanced Features (Days/Weeks)

### Feature Ideas

**1. Timeline View**
Show transcripts on a visual timeline
- Weekly/monthly view
- Confidence trends over time
- Activity heatmap

**2. Inline Editing**
Edit transcripts without leaving the app
- Rich text editor
- Auto-save
- Markdown preview

**3. Context Management UI**
Add/edit people, projects from UI
- Forms for each entity type
- Validation
- Auto-save to YAML

**4. Batch Operations**
Work with multiple transcripts
- Multi-select
- Combine operation
- Bulk export
- Delete multiple

**5. Export Options**
Export transcripts in different formats
- PDF generation
- DOCX export
- Plain text
- Custom templates

**6. Menu Bar Mode**
Background processing
- Status item in menu bar
- Quick actions
- Notification on completion
- Hotkey to open

**7. Quick Look Plugin**
Preview transcripts in Finder
- Spacebar preview
- Metadata display
- Search highlighting

**8. Share Extension**
Transcribe from other apps
- Files app integration
- Voice Memos integration
- Safari extension

## Distribution Options

### Option 1: Personal Use
Just use the binary you built. Share with friends via AirDrop.

### Option 2: GitHub Release
1. Create repo: `gh repo create protokoll-osx`
2. Push code: `git push`
3. Create release: `gh release create v1.0.0`
4. Attach .app bundle
5. Users download and run

### Option 3: TestFlight
1. Join Apple Developer Program ($99/year)
2. Archive in Xcode
3. Upload to App Store Connect
4. Invite beta testers
5. Distribute via TestFlight

### Option 4: App Store
1. Complete App Store Review Guidelines compliance
2. Add privacy policy
3. Add app icon (1024x1024)
4. Submit for review
5. Publish

### Option 5: Homebrew Cask
```bash
# Create a cask formula
brew create --cask protokoll
```

Users install with:
```bash
brew install --cask protokoll
```

## Maintenance

### Keeping Up with Protokoll CLI Updates
When the CLI updates:
1. Update CLI: `npm update -g @redaksjon/protokoll`
2. Test with new version
3. Update model lists if new models added
4. Rebuild app: `swift build -c release`

### Handling Bug Reports
1. Enable debug mode in Settings
2. Check `~/Library/Logs/Protokoll/` for logs
3. Review intermediate files
4. Fix and release update

## Community

### Share Your Work
- Post on Twitter/X with screenshots
- Share in Protokoll community
- Write a blog post about your experience
- Make a demo video

### Get Feedback
- Ask friends to try it
- Post in r/macapps
- Submit to Product Hunt
- Share in Swift/SwiftUI communities

### Contribute Back
If you add great features:
1. Fork this repo
2. Create feature branch
3. Submit pull request
4. Help others use Protokoll

## Learning Resources

### SwiftUI
- [Apple's SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Hacking with Swift](https://www.hackingwithswift.com)
- [SwiftUI by Example](https://www.hackingwithswift.com/quick-start/swiftui)

### macOS Development
- [AppKit & SwiftUI](https://developer.apple.com/documentation/swiftui)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos)
- [WWDC Videos](https://developer.apple.com/videos/)

### App Distribution
- [Distributing Your App](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Common Issues & Solutions

### "Command not found: protokoll"
**Solution**: Install the CLI first
```bash
npm install -g @redaksjon/protokoll
which protokoll  # Should print path
```

### "Build failed: module not found"
**Solution**: Clean and rebuild
```bash
swift package clean
swift build
```

### "App crashes on launch"
**Solution**: Run in debug mode to see logs
```bash
swift run  # See console output
```

### "Dark mode looks weird"
**Solution**: Check color definitions
- Use `.foregroundColor(.primary)` not `.black`
- Use `.background(Color(nsColor: .controlBackground))` not `.white`

### "YAML parsing fails"
**Solution**: Use a proper YAML library
- Add Yams to Package.swift
- Replace manual parsing in ProtokolService.swift

## Celebration 🎉

You built something cool! Take a moment to appreciate:

✅ You created a native macOS app from scratch
✅ You integrated with an existing CLI tool
✅ You designed a beautiful, intuitive UI
✅ You learned (or reinforced) SwiftUI
✅ You have a useful tool for yourself
✅ You can share it with others

## Questions?

If you get stuck:
1. Check the documentation files (README, QUICKSTART, etc.)
2. Review the source code comments
3. Look at Swift/SwiftUI documentation
4. Search for SwiftUI examples online
5. Ask in Swift/macOS developer communities

## Final Thought

This app is a **foundation**, not a destination. Feel free to:
- Modify it heavily
- Remove features you don't need
- Add features you want
- Change the design
- Make it your own

The code is clean, well-structured, and documented. It's meant to be a starting point for your vision.

Have fun! 🚀

---

**Remember**: The best way to learn is to build. Start small, iterate, and enjoy the process.
