# PicFacet

A native macOS app that adds right-click **Quick Actions** in Finder for converting, resizing, and adjusting DPI on image files.

---

## 🚨 Cloning? This is required.

**The Xcode project is not committed to this repo.** It's regenerated from `project.yml` by [xcodegen](https://github.com/yonaskolb/XcodeGen). After cloning you **must** run:

```bash
nix shell nixpkgs#xcodegen -c xcodegen generate # preferred, if you use Nix
open PicFacet.xcodeproj
```

No Nix? `brew install xcodegen` is fine.

If you skip this, there is no `.xcodeproj` to open. Re-run `xcodegen generate` any time you add, remove, or rename a source file.

---

## What it does

Right-click any image (or batch of images) in Finder and pick a PicFacet Quick Action:

- **Convert to** JPEG · PNG · WebP · TIFF · GIF · BMP · HEIC (both directions)
- **Resize** by percent presets (10/25/50/75/90%)
- **Change DPI** to 72 / 96 / 150 / 300 / 600 / 1200 / 2400 / 3600

Or pick **PicFacet…** to get the full picker window with every option in one place.

A menu bar icon hosts settings, a batch processor, and a "How to enable Quick Actions…" helper.

---

## Architecture

```
PicFacet.xcodeproj           (generated — gitignored)
│
├── PicFacet                 (main app, menu-bar resident, LSUIElement)
│   ├── PicFacetApp.swift
│   ├── AppDelegate.swift          — registers NSApp.servicesProvider
│   ├── ServiceProvider.swift      — two @objc entry points; NSUserData picks the operation
│   ├── ChooserWindow.swift        — full picker window for "PicFacet…"
│   ├── BatchWindow.swift          — drag-and-drop batch processor
│   ├── PicFacetDesign.swift       — PFDesign tokens + Liquid Glass modifiers
│   ├── OnboardingWindow.swift     — first-launch help window
│   ├── MenuBarController.swift    — NSStatusItem + settings
│   └── SettingsView.swift
│
├── PicFacetCoreTests        (Swift Testing, runs with the PicFacet scheme)
│
└── PicFacetCore             (shared framework, no UI)
    ├── ImageFormat.swift          — format enum + extension helpers
    ├── ImageProcessor.swift       — pipeline: BatchSelection + OutputPolicy in, one write per file (max 4 concurrent)
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

- **macOS 26+** (Liquid Glass APIs are used without fallbacks)
- **Xcode 26+**, Swift 6 language mode
- **Nix** preferred, or **Homebrew**
- **xcodegen** (`nix shell nixpkgs#xcodegen` or `brew install xcodegen`)

### Build & run

```bash
nix shell nixpkgs#xcodegen -c xcodegen generate
./script/build_and_run.sh
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
├── PicFacetCore/          ← framework sources + Info.plist
├── PicFacetCoreTests/     ← Swift Testing suite (runs spec/cases.json too)
├── spec/cases.json        ← platform-neutral behaviour cases
└── docs/roadmap/          ← parked future features
```

`PicFacet.xcodeproj/` and `build/` are gitignored. **Always re-run `xcodegen generate` after adding or removing source files.**

---

## Roadmap

- [x] Phase 1 — Project scaffold (xcodegen)
- [x] Phase 2 — Image engine (convert/resize/DPI, all formats incl. HEIC)
- [x] Phase 3 — NSServices Quick Actions (14 ops + chooser)
- [x] Phase 3.5 — full chooser window + onboarding
- [x] Phase 4 — Custom input panels (custom %, target width, target height in Chooser and Batch)
- [ ] Phase 5 — Menu bar progress indicator
- [x] Phase 6 — Full settings window
- [ ] Phase 7 — App icon, DMG, notarization
- [ ] Phase 8 — Pricing research ($1.99–$2.99 target)
- [ ] Phase 9 — Mac App Store submission
- [ ] Future — Windows release (parked; see [docs/roadmap/windows-port.md](docs/roadmap/windows-port.md))

## Current Gaps

- Verify Finder Quick Actions end-to-end after each generated build.
- Add menu bar progress while batches are running.
- Replace the generated/menu-bar symbol with final app icon assets.
- Prepare packaging, signing, notarization, and Mac App Store metadata.
