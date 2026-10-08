# PicFacet

A native macOS app that adds right-click **Quick Actions** in Finder for converting, resizing, compressing, cleaning and renaming image files.

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

- **Convert to** JPEG · PNG · WebP · HEIC · AVIF · TIFF · GIF · BMP · PDF, and **PDF pages → images** (one file per page)
- **Resize** by percent, exact width/height, or **fit long edge** (never enlarges)
- **Crop** to 1:1, 4:5, 3:2, 4:3, 16:9 or 9:16 (centre)
- **Quality** presets for lossy formats, and a **target file size** ("under 500 KB"): searches quality, then downscales
- **Metadata**: remove location (GPS + IPTC place) or remove everything except DPI/orientation
- **Watermark** with text or a logo, five positions, three sizes
- **Rename** with tokens: `{name}` `{n}` `{date}` `{width}` `{height}` `{format}`
- **Change DPI** to 72 / 96 / 150 / 300 / 600 / 1200 / 2400 / 3600

Or pick **PicFacet…** to get the full picker window with every option in one place. With the Finder extension enabled, **PicFacet…** and a **PicFacet Recipes** submenu appear directly in the top level of the right-click menu.

**Recipes** save a whole set of options under a name (Recipes menu in the Chooser and Batch windows; manage them in Settings). Run a recipe from Finder, the Shortcuts app, or a **watched folder**.

**Watched folders** run one or more recipes on each new image. Each recipe works from the original, so one drop can make several outputs (e.g. a WebP thumbnail and a 300 DPI TIFF). With one recipe, results go to `Processed/`; with several, to `Processed/<recipe name>/`. Options per folder:
- **Delete originals after processing** (asks first): the dropped file is deleted permanently, bypassing the Trash, and only after every recipe saved its result. A failure or a discarded result keeps the original.
- **Keep watching when PicFacet is closed**: registers the **PicFacet Watcher** login item (`Contents/Library/LoginItems/PicFacetWatcher.app`, `SMAppService.loginItem`), a background-only helper that starts at login and keeps watching after PicFacet quits. Needs a signed build; macOS may ask to allow it under System Settings → General → Login Items.

Each folder's file list is saved, so images added while nothing was watching are processed the next time watching starts.

**Shortcuts**: "Process Images" and "Run PicFacet Recipe" actions take images and return the processed files.

Every run reports the space saved ("Saved 4.2 MB (68%)") in the completion alert, the activity log, or a notification for background runs.

A menu bar icon hosts settings, a batch processor, and a "How to enable Quick Actions…" helper.

> WebP is encoded with a bundled **libwebp** 1.6.0 (via the [libwebp-Xcode](https://github.com/SDWebImage/libwebp-Xcode) Swift package, BSD licence; notice in `PicFacet/Resources/libwebp-LICENSE.txt`). ImageIO only decodes WebP. WebP output is sRGB with no EXIF, GPS or DPI. Quality 100 is lossless.

---

## Architecture

```
PicFacet.xcodeproj           (generated — gitignored)
│
├── PicFacet                 (main app, menu-bar resident, LSUIElement)
│   ├── PicFacetApp.swift
│   ├── AppDelegate.swift          — registers NSApp.servicesProvider; handles picfacet:// and open-file events
│   ├── ServiceProvider.swift      — two @objc entry points; NSUserData picks the operation
│   ├── Automation.swift           — recipe store, background runs, watched folders, login item control
│   ├── Shortcuts.swift            — App Intents: Process Images, Run PicFacet Recipe
│   ├── ChooserWindow.swift        — full picker window for "PicFacet…"
│   ├── BatchWindow.swift          — drag-and-drop batch processor
│   ├── PicFacetDesign.swift       — PFDesign tokens + Liquid Glass modifiers
│   ├── OnboardingWindow.swift     — first-launch help window
│   ├── MenuBarController.swift    — NSStatusItem + settings
│   ├── WindowControls.swift       — bottom status bar, appearance + Settings window controllers
│   └── SettingsView.swift
│
├── PicFacetWatcher          (background-only login item: watched folders while PicFacet is closed)
│   └── main.swift
│
├── PicFacetFinderSync       (sandboxed Finder Sync extension: top-level "PicFacet…" menu item)
│   └── FinderSync.swift           — sends selected paths as picfacet://open?path=… or picfacet://run?recipe=…&token=…
│
├── PicFacetCoreTests        (Swift Testing, runs with the PicFacet scheme)
│
└── PicFacetCore             (shared framework, no UI)
    ├── ImageFormat.swift          — format enum + extension helpers
    ├── ImageProcessor.swift       — pipeline: BatchSelection + OutputPolicy in, one write per file (max 4 concurrent)
    ├── Operations.swift           — metadata, crop, watermark and rename option types
    ├── Recipes.swift              — Recipe and WatchedFolder models
    ├── ConversionEngine.swift     — ImageIO read/encode (quality, orientation), PDF page rendering
    ├── CropEngine.swift / WatermarkEngine.swift / MetadataEngine.swift
    ├── TargetSizeEncoder.swift    — fit a byte budget: quality search, then downscale
    ├── WebPEncoder.swift          — libwebp encode (lossy / lossless)
    ├── FolderWatcher.swift        — folder watching shared by the app and PicFacet Watcher
    ├── ResizeEngine.swift         — CGContext high-quality resize
    ├── DPIEngine.swift            — per-format DPI metadata patching
    ├── FileOutputManager.swift    — output paths, dedup, overwrite rules
    ├── PicFacetSettings.swift     — UserDefaults model
    ├── ProcessingResult.swift
    └── PicFacetError.swift
```

### NSServices and the Finder Sync extension

Quick Actions (NSServices) always land in Finder's **Quick Actions** submenu. To get a top-level item, the app also ships a small Finder Sync extension. It does no image work: a sandboxed extension gets no file access for Finder's selection, so it passes the selected paths to the main app in a `picfacet://open?path=…` URL and the app opens the chooser. Enable it once in **System Settings → General → Login Items & Extensions → Finder**.

The extension reads the recipe list from the shared App Group and builds the **PicFacet Recipes** submenu. A recipe item sends `picfacet://run?recipe=…&token=…`. The token is a random secret the app stores in the App Group. Any app or web page can open a `picfacet://` link, so a `run` link without the right token only opens the Chooser with the recipe loaded and processes nothing until the user clicks Start. ### Shared settings (App Group)

The app, the Finder extension and PicFacet Watcher share settings through the App Group `$(TeamIdentifierPrefix)com.picfacet.shared`, set in each target's entitlements and its `PicFacetAppGroup` Info.plist key. A Team-ID-prefixed group is authorised for every target on the team without registering it per App ID. On first launch, the main app copies settings from the old `group.com.picfacet.shared` group (`PicFacetSettings.migrateLegacyAppGroupIfNeeded`). Unsigned builds have no team prefix and use plain `UserDefaults` files instead.

Why not *only* a Finder Sync extension? The first cut of this project used a Finder Sync Extension (the heavy `FIFinderSync` API used by Dropbox/iCloud). Every menu click died in the sandbox. NSServices runs in the main app's process, hands us file URLs directly via the pasteboard, needs no IPC, no App Groups, no bookmarks, and is App Store compatible. It's the right tool for "right-click → do a thing." See `refactor.md` for the full story.

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

`build_and_run.sh` installs the build to **/Applications/PicFacet.app** and launches it from there (`NO_INSTALL=1` runs it from the build folder instead). On macOS 27 the menu bar, and menu bar managers like Bartender, only handle an app's icon properly when the app runs from Applications.

It also signs with your **Apple Development** certificate when one is installed (team read from the certificate, or set `TEAM_ID`), so background folder watching works locally. `UNSIGNED=1` builds unsigned (background watching then off). `ALLOW_PROVISIONING=1` lets Xcode create or refresh App IDs and profiles on your developer account; it's only needed after adding a target or capability.

### Make a DMG

```bash
./script/make_dmg.sh            # → build/PicFacet-<version>.dmg
```

Archives a Release build and packages it with an Applications shortcut. With a **Developer ID Application** certificate installed it exports for distribution; set `NOTARY_PROFILE` (from `xcrun notarytool store-credentials`) to notarize and staple. Without one, the DMG holds the development-signed app, which opens on your own Macs but is blocked on everyone else's.

### First launch

The onboarding window appears automatically and walks you through enabling the Quick Actions you want. By design, **all PicFacet services ship turned off** so they don't clutter your right-click menu — you opt in to the ones you want via:

**System Settings → Keyboard → Keyboard Shortcuts → Services → Files and Folders / Pictures**

Tick the PicFacet entries you want. The **PicFacet…** entry is the most useful one — it opens the full picker for any image.

For a top-level right-click item, also enable the **PicFacet Finder Extension** (see below). Folder permissions (Desktop, Documents, Downloads, Full Disk Access) live in **Settings → File Access**.

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
- [x] Phase 5 — Menu bar progress indicator (ring icon + "Processing 3 of 10 files…" while any batch runs)
- [x] Phase 6 — Full settings window
- [ ] Phase 7 — App icon (in design), DMG (`script/make_dmg.sh` ready), notarization (needs a Developer ID certificate)
- [x] Phase 7.5 — Value features: quality, target size, metadata stripping, long edge, crop, watermark, rename, AVIF/PDF/WebP, recipes, watched folders (multi-recipe, background helper, delete originals), Shortcuts, savings report
- [ ] Phase 8 — Pricing: $2.99 launch price, recipes included
- [ ] Phase 9 — Mac App Store submission
- [ ] Future — Windows release (parked; see [docs/roadmap/windows-port.md](docs/roadmap/windows-port.md))

## Current Gaps

- Verify Finder Quick Actions end-to-end after each generated build.
- Replace the generated/menu-bar symbol with final app icon assets.
- Decide Mac App Store vs direct sale: the App Store needs the app sandboxed, which means reworking folder access for watched folders, the background helper, custom output folders and deletes.
- Prepare packaging, signing, notarization, and Mac App Store metadata.
