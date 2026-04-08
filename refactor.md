# PicFacet Refactor — Shared Container IPC

## Why the current code fails

The extension → main-app bridge relies on `NSWorkspace.shared.open("picfacet://…")`. On modern macOS, a **sandboxed Finder Sync Extension cannot call `NSWorkspace.open` on a custom URL scheme** — the call is silently denied by the sandbox. No logs, no errors, no file work. That's exactly what we're seeing.

Custom URL schemes, `DistributedNotificationCenter`, and XPC-via-mach-service are all blocked or unreliable from Finder Sync Extensions. There is **one** IPC path that Apple supports for this exact case and that also works inside the App Store sandbox:

> A **shared App Group container**, written to by the extension and watched by the main app, carrying file-system **security-scoped bookmarks** instead of raw paths.

This is how ImageOptim, Transloader, BetterZip, and every other "right-click in Finder to do X" app on the Mac App Store works.

---

## Target architecture

```
┌────────────────────────┐         App Group container          ┌──────────────────────┐
│ Finder Sync Extension  │         ~/Library/Group Containers/  │ Main App (menu bar)  │
│ (sandboxed)            │         group.com.picfacet.shared/   │ (sandboxed)          │
│                        │             requests/                │                      │
│ 1. User clicks menu    │ ─ write → {uuid}.json                │ 2. Folder watcher    │
│ 2. Create bookmarks    │                                      │    picks up file     │
│    for each selected   │                                      │ 3. Resolve bookmarks │
│    URL                 │                                      │ 4. Process images    │
│ 3. Serialise request   │                                      │ 5. Delete request    │
│    as JSON and drop    │                                      │                      │
│    in requests/        │                                      │                      │
└────────────────────────┘                                      └──────────────────────┘
```

### Why security-scoped bookmarks?

When Finder passes a URL to the extension, macOS temporarily extends the extension's sandbox to cover that URL. That permission **does not transfer** to any other process. A bookmark is a blob the extension can create *from* its temporary permission and the main app can *resolve* to get its own permission to the same file. This is the blessed mechanism and it works identically locally and in the App Store.

### Why file-watching (vs sockets / XPC / Distributed Notifications)?

- A file written into an App Group container **is** a supported IPC primitive — both processes have native permission to that directory.
- `DispatchSource.makeFileSystemObjectSource` gives sub-millisecond latency.
- No mach service registration, no entitlement surprises, no silent sandbox denials.
- Works in Xcode builds, works in Developer ID builds, works in App Store builds — identical code.

---

## Request file format

Path: `{groupContainer}/requests/{uuid}.json`

```json
{
  "op": "convert",
  "param": "jpeg",
  "bookmarks": [
    "base64-encoded-security-scoped-bookmark-data",
    "base64-encoded-security-scoped-bookmark-data"
  ],
  "createdAt": "2026-04-08T02:34:12Z"
}
```

- `op` — one of `convert`, `resizePercent`, `resizeWidth`, `resizeHeight`, `dpi`
- `param` — string form of the parameter (format raw value, percent, pixel count, dpi number)
- `bookmarks` — array of base64-encoded security-scoped bookmark blobs, one per selected file
- `createdAt` — for debugging / cleanup of stale requests

Main app deletes the request file after the batch completes so the watcher doesn't re-fire.

---

## Detailed change list

### 1. Entitlements — both targets get sandbox + App Group

Both the main app and the extension must share the App Group `group.com.picfacet.shared`. This is the only way they can see the same folder.

- `PicFacet/PicFacet.entitlements`
  - `com.apple.security.app-sandbox` = YES
  - `com.apple.security.application-groups` = [`group.com.picfacet.shared`]
  - `com.apple.security.files.user-selected.read-write` = YES  (needed when the user uses the file dialogs in Settings later)
  - `com.apple.security.files.bookmarks.app-scope` = YES
- `PicFacetExtension/PicFacetExtension.entitlements`
  - Same four keys, identical values

### 2. New file: `PicFacetCore/SharedContainer.swift`

Central helper for resolving the group container URL and the requests subfolder. Ensures the `requests/` directory exists. Shared by extension and main app so they agree on the layout.

### 3. Refactor `PicFacetCore/OperationBridge.swift`

Drop the URL-scheme code entirely. New API:

```swift
public enum OperationBridge {
    public static let opConvert       = "convert"
    public static let opResizePercent = "resizePercent"
    public static let opResizeWidth   = "resizeWidth"
    public static let opResizeHeight  = "resizeHeight"
    public static let opDPI           = "dpi"

    public struct Request: Codable {
        public let op: String
        public let param: String
        public let bookmarks: [Data]
        public let createdAt: Date
    }

    /// Called from the extension. Builds security-scoped bookmarks for each
    /// URL, serialises a Request, writes it into the shared container.
    public static func postRequest(op: String, param: String, urls: [URL]) throws

    /// Called from the main app. Reads and JSON-decodes a request file.
    public static func readRequest(at url: URL) throws -> Request

    /// Resolves each bookmark to a URL, calling `startAccessingSecurityScopedResource`.
    /// Returns the URLs AND a cleanup closure the caller runs when done.
    public static func resolveBookmarks(_ bookmarks: [Data]) -> (urls: [URL], stopAccess: () -> Void)
}
```

Bookmarks are created with `URL.bookmarkData(options: .withSecurityScope, …)` in the extension and resolved with `URL(resolvingBookmarkData:options: .withSecurityScope, …)` in the main app.

### 4. Rewrite `PicFacetExtension/FinderSync.swift` action handlers

Every action now:

1. Gets the selected URLs from `FIFinderSyncController`
2. Calls `OperationBridge.postRequest(op:param:urls:)`
3. Logs success/failure

No more `NSWorkspace.open`. No more URL schemes.

### 5. New file: `PicFacet/RequestWatcher.swift`

Runs inside the main app. Watches `{groupContainer}/requests/` using `DispatchSource.makeFileSystemObjectSource(fileDescriptor:eventMask:.write, …)`. On each change:

1. List `.json` files in the folder
2. For each: read, decode, resolve bookmarks, hand to `ImageProcessor`, delete file after completion
3. Swallow any files that fail to decode (delete them so they don't jam the queue)

Also does an initial scan at launch to pick up any requests created while the main app wasn't running.

### 6. `PicFacet/AppDelegate.swift` — wire up the watcher

- Drop `application(_:open:)` URL handling
- Start a `RequestWatcher` in `applicationDidFinishLaunching`
- Keep it alive as a property

### 7. Keep the `ImageProcessor` changes

The `startAccessingSecurityScopedResource()` calls we added in the batch executor are still needed — they pair with the bookmark resolution in the main app.

### 8. Project regen

Run `xcodegen generate` to re-sync the new `SharedContainer.swift` and `RequestWatcher.swift` files into the Xcode project.

---

## Developer-side setup (one-time, you do this in Xcode)

Both sandboxing and App Groups require a paid Apple Developer Team to be set on each target. After pulling this refactor:

1. Open `PicFacet.xcodeproj`
2. Select the **PicFacet** target → Signing & Capabilities → Team = your Apple ID
3. Click **+ Capability** → add **App Groups** → tick `group.com.picfacet.shared` (or add it)
4. Repeat 2–3 for the **PicFacetExtension** target (same team, same group)
5. Build → Run

First right-click → Convert should write the output file next to the source. Live log visible with:

```bash
log stream --predicate 'eventMessage contains "PicFacet"' --level debug
```

---

## What this unlocks

- **Local testing now**: works on your MacBook immediately with your paid dev account
- **App Store later**: zero additional architectural changes. The same entitlements that let this work locally are the ones Apple requires for the store. You'll only need a notarized build + store submission paperwork.
- **Phase 4/5 (custom input panels)**: trivial to add. Extension drops a request labelled `awaitingInput`, main app shows a SwiftUI sheet, posts the completed request itself.
- **Phase 6 (progress in menu bar)**: the main app already knows about every job since it's the one doing the work.

---

## Status after implementation (2026-04-08)

Refactor completed and builds clean. However, a **new blocker** emerged during testing:

### What works
- Extension initialises, `FinderSync` logs on launch
- Right-click menu appears correctly on image files
- App Group container opens successfully even on free Personal Team (`container_create_or_lookup_app_group_path_by_app_group_identifier: success` in the logs)
- Extension can read `PicFacetSettings.shared.resizePresets` from the shared defaults
- Main app's `RequestWatcher` starts and monitors the requests folder

### What doesn't work
- **Menu item clicks don't reach `handleConvert` / `handleResizePreset` / `handleDPI`**
- No `[PicFacet] Ext click` log line appears after a click
- No `.json` request file is written to the shared container
- The `/tmp/picfacet-click.txt` proof-of-life test has been added as the next diagnostic — if that file doesn't appear on click, the Objective-C action target is being lost somewhere between menu construction and click delivery.

### Hypotheses to test next
1. Action target is being released — `target = self` holds a weak pointer while the menu is shown; the extension might be getting suspended between menu creation and click
2. Finder is caching a stale extension binary — try `pluginkit -r /path/to/extension` and rebuild
3. The `representedObject` approach breaks when the extension process is re-spawned for the click
4. The menu items themselves need to be retained as properties on the `FinderSync` instance

## Risk / unknowns

- **App Group id must be available to your team**. If your Apple ID can't register `group.com.picfacet.shared`, pick any unique name (e.g. `group.com.yourname.picfacet`) and update the single constant in `SharedContainer.swift` + both entitlements files.
- **Stale requests**: if the main app isn't running when a request is posted, it sits in the queue until the app launches. Mitigation: initial scan at launch. Acceptable for MVP.
- **Multiple requests in flight**: file-watching sees each write independently, processor is already concurrency-safe (max 4 at a time). Fine.
