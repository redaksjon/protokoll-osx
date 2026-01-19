# 🚀 Quick Start - Protokoll for macOS

## TL;DR - Get It Running Now

```bash
cd /Users/tobrien/gitw/redaksjon/protokoll-osx
./create-app.sh
open Protokoll.app
```

That's it! The app should launch.

## What Just Happened?

1. **`./create-app.sh`** - Builds the Swift code and packages it as a proper macOS app bundle
2. **`open Protokoll.app`** - Launches the app

## If You Don't See a Window

1. **Press Cmd+Tab** - The app might be hidden behind other windows
2. **Check your Dock** - Look for the Protokoll icon
3. **Check Console.app** - Look for any error messages from Protokoll

## First Time Setup

Once the app opens:

1. **Open Settings** (Cmd+,)
2. **General tab**: Enter your OpenAI API key
3. **Paths tab**: Set your directories
4. **Save Settings**

## Now What?

1. **Click Transcribe tab**
2. **Drag an audio file** onto the drop zone
3. **Watch it process**
4. **View results** in Transcripts tab

## Alternative: Use Xcode

If you prefer Xcode:

```bash
open Package.swift
```

Then press ⌘+R to run.

## Troubleshooting

**"Permission denied" on create-app.sh?**
```bash
chmod +x create-app.sh
```

**"Command not found: swift"?**
Install Xcode Command Line Tools:
```bash
xcode-select --install
```

**App launches but no window?**
Check Console.app for error messages. The app might be waiting for you to press Cmd+Tab to bring it forward.

## Full Documentation

- **README.md** - Complete overview
- **QUICKSTART.md** - Detailed getting started guide
- **OVERVIEW.md** - Technical details
- **DESIGN.md** - Design philosophy

## That's It!

You should now have Protokoll running as a native macOS app. Enjoy! 🎉
