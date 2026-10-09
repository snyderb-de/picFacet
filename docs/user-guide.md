# PicFacet user guide

PicFacet is a menu bar app for converting, resizing, compressing, cleaning and renaming images. It has no Dock icon: you use it from Finder's right-click menu, its menu bar icon, the Shortcuts app, or folders it watches.

Install it in **Applications**. On macOS 27 the menu bar (and menu bar managers like Bartender) only handle the icon properly for apps run from there.

---

## Ways to use it

| Where | What it does |
|---|---|
| **Finder → right-click → PicFacet…** | Opens the **Chooser** with the selected images: every option in one window. Needs the Finder extension (see below). |
| **Finder → right-click → PicFacet Recipes** | Runs a saved recipe on the selection straight away. |
| **Finder → right-click → Quick Actions → PicFacet: …** | One-click actions: Convert to JPEG/PNG/WebP/HEIC/AVIF/…, Resize, Fit Within 1920 px, Crop Square, Optimize for Web, Shrink Under 1 MB, Remove Location Data, Remove All Metadata, Set DPI, Convert PDF to PNG/JPEG. |
| **Menu bar icon → Batch Processor…** (⌘B) | Drop images or PDFs into a window and process them, with a per-file activity log. Double-clicking the app while it runs opens this too. |
| **Shortcuts app** | "Process Images" and "Run PicFacet Recipe" actions take images and return the processed files. |
| **Watched folders** (Settings) | New images dropped in a folder are run through one or more recipes automatically. |

The menu bar icon turns into a progress ring while anything is processing ("Processing 3 of 10 files…"), then shows a checkmark briefly.

---

## Processing options

Every window shows the same options. Any combination works; each file is written once.

| Option | Choices |
|---|---|
| **Format** | JPEG, PNG, WebP, TIFF, GIF, BMP, HEIC, AVIF, PDF, or No Change |
| **Quality** | Maximum (95), High (85), Web (75), Email (60), Small (40). JPEG, WebP, HEIC and AVIF only. WebP at 100 is lossless. |
| **Resize** | 25 / 50 / 75 %, custom %, exact width, exact height, or **Fit long edge** (never enlarges) |
| **Crop** | Centre crop to 1:1, 4:5, 3:2, 4:3, 16:9 or 9:16 (done before resizing) |
| **File size** | Under 200 KB / 500 KB / 1 MB / 2 MB / 5 MB, or custom. Lowers quality first, then shrinks the image. If the limit can't be met, the smallest version is saved and the file is flagged. |
| **DPI** | 72 to 3600 |
| **Metadata** | Remove location (GPS and place names; camera info stays) or remove all (keeps only DPI and orientation) |
| **Watermark** | Text or a logo image; five positions; small / medium / large |
| **Rename** | A name pattern, built in the Rename window (below) |

Rotated phone photos are turned upright before cropping or watermarking, so results match what you see.

PDFs: choose a Format and each page is saved as its own image (`report-p1.png`, `report-p2.png`…).

### Rename window

Click the Rename row's pencil to open it.

- **Tokens**: drag one into the name, or click it to add it at the end. `{name}` original name, `{n}` number in the batch (01, 02…), `{date}` today, `{width}` / `{height}` size of the saved image, `{format}` file type.
- **Examples**: click one to use it, e.g. `{name}-web`, `vacation-{n}`, `{date}-{n}`.
- **Preview**: your first three files' old and new names, using your crop and resize settings.
- **Show Me How**: a short demo with play, pause and restart. Close it any time; it never changes your pattern.

The file extension is always added for you. Names never overwrite an existing file; PicFacet adds `-1`, `-2`… instead.

---

## Recipes

A recipe saves a full set of options under a name ("Blog photos": long edge 1600, WebP, quality 75, remove location).

- **Create**: Settings → Recipes → **New Recipe…**, or set options in the Chooser or Batch window and choose **Recipes → Save Current as Recipe…**
- **Use**: Recipes menu in the Chooser and Batch window, Finder's **PicFacet Recipes** submenu, the Shortcuts app, or a watched folder.
- **Edit or delete**: Settings → Recipes, pencil or trash icon.

---

## Watched folders

Settings → Watched Folders → **Add Folder…**, then pick one or more recipes for it.

- Each recipe works from the original image, so one drop can make several outputs (for example a WebP thumbnail and a 300 DPI TIFF).
- Results go to a `Processed` subfolder, or `Processed/<recipe name>/` when the folder has several recipes. The original stays where it is.
- **Delete originals after processing** (asks first): the dropped file is deleted permanently, not to the Trash, and only after every recipe has saved its result. If anything fails, or a result is discarded because it wasn't smaller, the original stays.
- **Keep watching when PicFacet is closed**: a small background helper (PicFacet Watcher) keeps watching after you quit and starts at login. macOS may ask you to allow it in System Settings → General → Login Items.
- Images added while nothing was watching are processed the next time watching starts.

---

## Settings worth knowing

| Setting | Effect |
|---|---|
| Overwrite source files | Replace the original instead of saving beside it |
| Keep result only if smaller | Discard a result that isn't smaller and keep the original |
| Delete original after conversion | Remove the source once the converted file is saved |
| Save unsupported formats as JPEG | For RAW, ICO, PSD and other read-only formats |
| Show a summary after background runs | Notification with files saved and space saved |
| File Access | Ask for Desktop/Documents/Downloads access up front, or open Full Disk Access |

---

## First-time setup

1. Move PicFacet to **Applications** and open it.
2. Turn on the Quick Actions you want: **System Settings → Keyboard → Keyboard Shortcuts → Services → Files and Folders / Pictures**, tick the PicFacet entries. (They ship turned off so your right-click menu stays tidy.)
3. For the top-level **PicFacet…** and **PicFacet Recipes** items, enable **PicFacet Finder Extension** in **System Settings → General → Login Items & Extensions → Finder**.

The menu bar icon → **How to enable Quick Actions…** reopens these steps.

If the menu bar icon is missing, see [menu bar troubleshooting](menu-bar-troubleshooting.md).
