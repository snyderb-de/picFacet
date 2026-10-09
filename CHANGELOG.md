# Changelog

## Unreleased (next: 1.3.0)

Launch price: **$2.99**, recipes included.

### Processing
- Quality presets for JPEG, WebP, HEIC and AVIF
- Target file size: searches quality, then downscales; flags files it can't get under the limit
- Metadata: remove location (GPS and IPTC place) or remove everything except DPI and orientation
- Fit long edge, centre crop to a ratio, text or logo watermark
- Rename patterns with `{name}` `{n}` `{date}` `{width}` `{height}` `{format}`
- WebP output via bundled libwebp 1.6.0 (ImageIO only decodes WebP); quality 100 is lossless
- AVIF and PDF output; PDF pages to images
- Rotated photos are made upright before processing
- Resizing GIF, greyscale and CMYK images no longer fails

### Recipes and automation
- Recipes: save a full set of options; use them in the Chooser, Batch window, Finder's PicFacet Recipes menu, Shortcuts and watched folders; create and edit them in Settings
- Watched folders run one or more recipes per image, each from the original, into `Processed/`
- Optional permanent deletion of originals, only after every recipe saved its result
- PicFacet Watcher login item keeps folders watched when the app is closed
- Files added while nothing was watching are processed when watching starts
- Shortcuts actions: Process Images, Run PicFacet Recipe
- New Quick Actions: Convert to AVIF, Convert PDF to PNG/JPEG, Fit Within 1920 px, Crop Square, Optimize for Web, Shrink Under 1 MB, Remove Location Data, Remove All Metadata

### Interface
- Rename window: draggable tokens, examples, live preview, drag hint and a "Show Me How" demo
- Menu bar progress ring and "Processing 3 of 10 files…" for every run
- Space saved shown in alerts, the activity log and notifications
- Batch and Chooser windows fit every option without scrolling
- Double-clicking the running app opens the Batch window

### Under the hood
- Settings moved to a team-prefixed App Group (`<TeamID>.com.picfacet.shared`), migrated once from `group.com.picfacet.shared`
- Menu bar icon has a fixed name, so its position is remembered (and works with Bartender)
- `build_and_run.sh` signs with your Apple Development certificate and installs to /Applications
- `make_dmg.sh` builds a Release DMG; exports with Developer ID and notarizes when available

## 1.2.3 (build 7)
- Five colour themes: Dracula, One Dark, Nord, Solarized, Gruvbox
- Image Queue stats for the queue and the running batch
