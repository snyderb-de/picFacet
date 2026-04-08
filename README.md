# PicFacet

A native macOS app that adds right-click **Quick Actions** in Finder for converting, resizing, and adjusting DPI on image files.

---

## 🚨 Cloning? This is required.

**The Xcode project is not committed to this repo.** It's regenerated from `project.yml` by [xcodegen](https://github.com/yonaskolb/XcodeGen). After cloning you **must** run:

```bash
brew install xcodegen      # one time, if you don't have it
xcodegen generate          # creates PicFacet.xcodeproj
open PicFacet.xcodeproj
```

If you skip this, there is no `.xcodeproj` to open. Re-run `xcodegen generate` any time you add, remove, or rename a source file.

---

## What it does

Right-click any image (or batch of images) in Finder and pick a PicFacet Quick Action:

- **Convert to** JPEG · PNG · WebP · TIFF · GIF · BMP · HEIC (both directions)
- **Resize** by percent presets (10/25/50/75/90%)
- **Change DPI** to 72 / 96 / 150 / 300 / 600 / 1200 / 2400 / 3600

Or pick **PicFacet…** to get the full Liquid Glass picker window with every option in one place.

A menu bar icon hosts settings and a "How to enable Quick Actions…" helper.

---

## Architecture

```
PicFacet.xcodeproj           (generated — gitignored)
│
├── PicFacet                 (main app, menu-bar resident, LSUIElement)
│   ├── PicFacetApp.swift
│   ├── AppDelegate.swift          — registers NSApp.servicesProvider
│   ├── ServiceProvider.swift      — @objc handlers for every Quick Action
│   ├── ChooserWindow.swift        — Liquid Glass picker for "PicFacet…"
│   ├── OnboardingWindow.swift     — first-launch help window
│   ├── MenuBarController.swift    — NSStatusItem + settings
│   └── SettingsView.swift
│
└── PicFacetCore             (shared framework)
    ├── ImageFormat.swift          — format enum + extension helpers
    ├── ImageProcessor.swift       — orchestrator (OperationQueue, max 4 concurrent)
    ├── ConversionEngine.swift     — ImageIO read/write
    ├── ResizeEngine.swift         — CGContext high-quality resize
    ├── DPIEngine.swift            — per-format DPI metadata patching
    ├── FileOutputManager.swift    — output paths, dedup, overwrite rules
    ├── PicFacetSettings.swift     — UserDefaults model
    ├── ProcessingResult.swift
    └── PicFacetError.swift
```

### Why NSServices instead of a Finder Sync Extension?

The first cut of this project used a Finder Sync Extension (the heavy `FIFinderSync` API used by Dropbox/iCloud). Every menu click died in the sandbox. NSServices runs in the main app's process, hands us file URLs directly via the pasteboard, needs no IPC, no App Groups, no bookmarks, and is App Store compatible. It's the right tool for "right-click → do a thing." See `refactor.md` for the full story.

---

## Developer Setup

### Prerequisites

- **macOS 26 (Tahoe)** — required for Liquid Glass
- **Xcode 26+**
- **Homebrew**
- **xcodegen** (`brew install xcodegen`)

### Build & run

```bash
xcodegen generate
open PicFacet.xcodeproj
```

In Xcode: select the **PicFacet** target → **Signing & Capabilities** → set your Team (free Personal Team is fine for local testing). Then **⌘R**.

### First launch

The onboarding window appears automatically and walks you through enabling the Quick Actions you want. By design, **all PicFacet services ship turned off** so they don't clutter your right-click menu — you opt in to the ones you want via:

**System Settings → Keyboard → Keyboard Shortcuts → Services → Files and Folders / Pictures**

Tick the PicFacet entries you want. The **PicFacet…** entry is the most useful one — it opens the full picker for any image.

You can re-open the onboarding window any time from the menu bar icon → **How to enable Quick Actions…**

### Tail the logs

```bash
log stream --predicate 'process == "PicFacet"' --level debug | grep PicFacet
```

You should see `[PicFacet] Service fired — N image(s)` after each click.

---

## Apple Developer Account

- **Free Personal Team** ($0) — fine for local builds and testing on your own Mac
- **Paid Developer Program** ($99/year) — required for notarization, Developer ID distribution, and Mac App Store submission

---

## Repo Layout

```
.
├── README.md              ← this file
├── refactor.md            ← history of the Finder-Sync → NSServices pivot
├── project.yml            ← xcodegen config (source of truth)
├── .gitignore
├── PicFacet/              ← main app sources, Info.plist, entitlements
└── PicFacetCore/          ← framework sources + Info.plist
```

`PicFacet.xcodeproj/` and `build/` are gitignored. **Always re-run `xcodegen generate` after adding or removing source files.**

---

## Roadmap

- [x] Phase 1 — Project scaffold (xcodegen)
- [x] Phase 2 — Image engine (convert/resize/DPI, all formats incl. HEIC)
- [x] Phase 3 — NSServices Quick Actions (14 ops + chooser)
- [x] Phase 3.5 — Liquid Glass chooser window + onboarding
- [ ] Phase 4 — Custom input panels (By Percent / Max Width / Max Height with proportional toggle)
- [ ] Phase 5 — Menu bar progress indicator
- [ ] Phase 6 — Full settings window
- [ ] Phase 7 — App icon, DMG, notarization
- [ ] Phase 8 — Pricing research ($1.99–$2.99 target)
- [ ] Phase 9 — Mac App Store submission
