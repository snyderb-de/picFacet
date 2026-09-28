# Future feature: Windows release

Status: **not started**. Parked until there's evidence of Windows demand.

## Decision summary

- Build a **separate native Windows app** (C# / .NET 9 + WinUI 3). Share the
  *behaviour spec*, not code.
- The macOS app stays Swift + SwiftUI with native Liquid Glass. No cross-platform
  UI framework (Tauri/Electron) — it would throw away the native Mac UI.
- A shared Rust engine (libvips / `image` crate) called from both apps is only
  worth it if a third platform or a CLI appears.
- Consider shipping a **Windows CLI first** if demand is uncertain. It delivers
  most of the value without Explorer integration or code signing.

## Shared behaviour spec

[`spec/cases.json`](../../spec/cases.json) is the contract. It holds:

- `serviceCommands` — the action grammar used by Finder services
  (`convert:png;resize:50%;dpi:300`). Windows should use the same strings for
  its Explorer commands.
- `pipeline` — end-to-end cases: source file, selection, output policy, and the
  expected files, output name, pixel size, DPI, and whether the source is left
  untouched.

The macOS suite runs every case (`PicFacetCoreTests/SharedSpecTests.swift`).
The Windows test suite must load the same file and pass every case. New
behaviour goes into `cases.json` first, so both platforms stay in step.

### Behaviour the port must match

- **One write per file.** Convert → resize → DPI are applied in memory, then
  written once. No intermediate files.
- **Output naming.**
  - Convert: `name.<newext>`, deduplicated as `name-1.<ext>`, `name-2.<ext>`…
    unless *overwrite source* is on.
  - Same-format edits (resize, DPI): `name-picfacet.<ext>` next to the source,
    or the source itself when *overwrite source* is on.
  - A custom output folder replaces the source folder.
- **Keep result only if smaller.** Compare byte size of the new file with the
  source. Discard the new file if it isn't smaller; the source is untouched even
  when overwriting. DPI-only changes are exempt.
- **Staged writes.** Write to a hidden temp file beside the destination, then
  move it into place. A failed write must never damage the source.
- **Delete original after convert** only when the convert result was kept.
- **DPI** must be readable back by the platform's image APIs for JPEG, PNG,
  TIFF and HEIC.
- **Settings snapshot.** Output settings are captured once per batch.
- **Concurrency.** Up to 4 files in flight; progress counts files, not steps.

## Windows work list

### Engine (`PicFacet.Core`, .NET class library)
- [ ] `BatchSelection`, `OutputPolicy`, `ProcessingResult` value types
- [ ] Service-command parser
- [ ] Read/write via WIC (Windows Imaging Component)
- [ ] WebP **encode**: WIC decodes only. Add libwebp or Magick.NET.
- [ ] HEIC: needs Microsoft's HEIF + HEVC extensions. Detect absence and show a
      clear error (like the WebP message on macOS).
- [ ] Resize with high-quality interpolation (WIC `IWICBitmapScaler`, Fant or
      HighQualityCubic)
- [ ] Per-format DPI metadata (JFIF density, PNG pHYs, TIFF resolution) —
      same pitfall as `DPIEngine.swift`: update every place the value lives
- [ ] Staged write + size check + commit
- [ ] Test project loads `spec/cases.json` and runs every case

### Explorer integration
- [ ] `IExplorerCommand` handler for the Windows 11 context menu
- [ ] MSIX package with a sparse-package identity (required for the modern menu)
- [ ] Legacy registry verbs as a fallback ("Show more options" menu)
- [ ] **Single instance**: Explorer may launch one process per selected file.
      Forward file lists to the running instance (named pipe) and batch them.

### UI (WinUI 3)
- [ ] Chooser window (format / resize / DPI chips, summary, Start)
- [ ] Batch window (drop zone, file list with async thumbnails, progress)
- [ ] Settings (same keys and defaults as `PicFacetSettings.swift`)
- [ ] Tray icon (equivalent of the macOS menu bar item)
- [ ] Mica / Acrylic materials as the Liquid Glass counterpart

### Release
- [ ] Code-signing certificate (~$200–400/yr) or Microsoft Store submission
- [ ] Installer / MSIX pipeline in CI
- [ ] Decide pricing: paid, free, or Store

## Open questions

- Is there real Windows demand?
- Paid, free, or Store?
- Repo layout: proposal is one repo with `mac/`, `windows/` and the shared
  `spec/` at the root. Today the Mac project lives at the root; move it when the
  Windows work starts.

## Rough effort

- Engine + spec tests + Explorer menu: 1–2 weeks
- Windows UI + installer: 1–2 weeks
- Packaging and signing tend to take longer than the code.
