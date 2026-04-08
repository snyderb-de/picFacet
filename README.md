# PicFacet

A native macOS app that adds a right-click menu in Finder for quickly converting, resizing, and adjusting DPI on image files.

## End Goal

- **Direct download DMG** for early testers (current target)
- **Mac App Store** release at a fair price — likely **$1.99 – $2.99 one-time purchase**
- Menu-bar-resident (no Dock icon), minimal UI, everything driven from the Finder right-click menu

---

## Features (Planned)

### Right-click menu on any image file in Finder

```
PicFacet
├── Convert to →  JPEG · PNG · WebP · TIFF · GIF · BMP · HEIC
│
├── Resize →
│   ├── 25% / 50% / 75%           (configurable presets)
│   ├── By Percent…               (custom input panel)
│   ├── Max Width…                (custom input panel)
│   ├── Max Height…               (custom input panel)
│   └── ✓ Proportional            (toggle, on by default)
│
└── Change DPI →  72 · 96 · 150 · 300 · 600 · 1200 · 2400 · 3600
```

### Settings (via menu bar icon)

- Overwrite source file (on/off)
- Only resize if smaller than target (on/off)
- Delete original after convert (on/off)
- Output: same folder as source (default) or custom folder
- Resize presets (up to 5, editable)

### Batch support
Select N images → right-click → apply to all. Max 4 concurrent jobs. Progress indicator in menu bar.

---

## Architecture

```
PicFacet.xcodeproj (generated from project.yml via xcodegen)
│
├── PicFacet              (main app, menu bar resident, non-sandboxed dev / sandboxed for MAS)
│   ├── PicFacetApp.swift
│   ├── AppDelegate.swift          — dispatches operations to ImageProcessor
│   ├── MenuBarController.swift    — NSStatusItem + settings window
│   ├── RequestWatcher.swift       — watches App Group container for requests
│   └── SettingsView.swift         — SwiftUI settings (Phase 6)
│
├── PicFacetExtension     (Finder Sync Extension, sandboxed — required by macOS)
│   └── FinderSync.swift           — builds context menu, posts requests
│
└── PicFacetCore          (shared framework)
    ├── ImageFormat.swift          — format enum + file extension helpers
    ├── ImageProcessor.swift       — orchestrator (OperationQueue, max 4 concurrent)
    ├── ConversionEngine.swift     — ImageIO read/write
    ├── ResizeEngine.swift         — CGContext high-quality resize
    ├── DPIEngine.swift            — per-format DPI metadata patching
    ├── FileOutputManager.swift    — output paths, dedup, overwrite rules
    ├── PicFacetSettings.swift     — shared UserDefaults model
    ├── SharedContainer.swift      — App Group container layout
    ├── OperationBridge.swift      — request serialisation + security-scoped bookmarks
    ├── ProcessingResult.swift     — result type
    └── PicFacetError.swift        — error types
```

### IPC Flow (Extension → Main App)

macOS forces Finder Sync Extensions to be sandboxed. They cannot write files to arbitrary locations. The bridge:

```
1. User clicks a menu item in Finder
   ↓
2. Extension creates security-scoped bookmarks for selected URLs
   ↓
3. Extension writes {uuid}.json request file into App Group shared container
   (~/Library/Group Containers/group.com.picfacet.shared/requests/)
   ↓
4. Main app's RequestWatcher (DispatchSourceFileSystemObject) notices the file
   ↓
5. Main app resolves bookmarks, processes files via ImageProcessor
   ↓
6. Main app deletes the request file
```

This is the only pattern that works both on direct-distribution builds AND the App Store sandbox — no refactor required for App Store submission.

---

## Status

### Completed

- ✅ **Phase 1** — Xcode project scaffold (three targets, entitlements, xcodegen config)
- ✅ **Phase 2** — Full image engine in `PicFacetCore` (convert, resize, DPI — all ImageIO-backed, supports HEIC both directions)
- ✅ **Phase 3** — Finder Sync Extension with Convert / Resize / Change DPI submenus
- ✅ **Architecture refactor** — shared-container bookmark-based IPC (see `refactor.md`)
- ✅ Builds clean, signs with Personal Team, extension appears in Finder right-click menu

### 🔴 Current Blocker

**Menu clicks in the extension do not reach the handler code.** We can see the extension initialise and build the menu (confirmed via `log stream`), and we can see the App Group container open successfully (free Personal Team does allow this on macOS, contrary to common assumption). However, after clicking **Convert to → JPEG**, none of our `NSLog` lines fire and no request file is written to the shared container.

Active diagnostic: an unconditional `/tmp/picfacet-click.txt` write was added to the top of `handleConvert`. If the file doesn't appear after a click, the `@objc` action target is being lost (likely due to how Finder caches the extension, or a target ownership issue) — that's the next thing to investigate.

### Things already tried and ruled out

| Approach | Result |
|---|---|
| `NSWorkspace.open("picfacet://…")` from extension | Silently denied by sandbox |
| `DistributedNotificationCenter` with userInfo | Sandbox strips userInfo from sender |
| Removing the sandbox from the extension | macOS refuses to load unsandboxed Finder Sync extensions (menu disappears) |
| `application(_:open:)` URL handler in main app | Never fires because step 1 is blocked |
| Shared App Group container + bookmarks | Container works, but menu click still not firing — current blocker |

### Next Steps (in order)

1. **Unblock click handler** — the `/tmp/picfacet-click.txt` test will tell us if `handleConvert` is even running. If not: check whether `target = self` is being GC'd, try storing menu item references as properties, or re-register the extension with `pluginkit` after each build.
2. **Phase 4** — Custom input panels for By Percent / Max Width / Max Height (SwiftUI sheets in the main app, triggered by a special request type from the extension)
3. **Phase 5** — Menu bar progress indicator (spinner while jobs run, configurable position in settings)
4. **Phase 6** — Full settings window
5. **Phase 7** — App icon, DMG packaging, notarization for direct distribution
6. **Phase 8** — Pricing research (compare to similar utilities — ImageOptim is free, File Juicer is $18, Permute is $15, cleaner one-purpose tools tend to sit at $1.99–$4.99)
7. **Phase 9** — App Store submission (architecture already compatible, just needs paid Developer Program, proper bundle IDs, and screenshots)

---

## Developer Setup

### Prerequisites

- **macOS 11+**
- **Xcode 15+**
- **Homebrew**
- **xcodegen** (`brew install xcodegen`)

### First build

```bash
# 1. Generate the Xcode project
xcodegen generate

# 2. Open in Xcode
open PicFacet.xcodeproj
```

In Xcode:

1. Select the **PicFacet** target → **Signing & Capabilities** → set your Team
2. Confirm **App Groups** capability is present with `group.com.picfacet.shared` listed
3. Repeat for the **PicFacetExtension** target (same team, same App Group)
4. **⌘B** to build, **⌘R** to run

### Enable the extension

After first run:
**System Settings → General → Login Items & Extensions → Extensions (at bottom) → Added Extensions** → enable **PicFacetExtension**.

### Tail the logs

```bash
log stream --predicate 'process == "PicFacetExtension" OR process == "PicFacet"' --level debug | grep PicFacet
```

---

## Apple Developer Account

- **Free Personal Team** ($0) — works for local testing. App Groups DO work on macOS (contrary to common belief — tested and confirmed).
- **Paid Developer Program** ($99/year) — required for Developer ID notarization, Mac App Store submission, and distribution to other machines.

**For MVP on your own Mac:** free tier is sufficient. Upgrade to paid when ready to ship.

---

## Repo Layout

```
.
├── README.md              ← this file
├── refactor.md            ← detailed record of the IPC refactor
├── project.yml            ← xcodegen config (source of truth for targets)
├── PicFacet.xcodeproj     ← generated — do not edit by hand
├── PicFacet/              ← main app sources + entitlements + Info.plist
├── PicFacetExtension/     ← Finder Sync Extension sources + entitlements + Info.plist
└── PicFacetCore/          ← shared framework sources + Info.plist
```

Anytime you add or remove a source file, re-run `xcodegen generate`.
