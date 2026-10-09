# Menu bar icon troubleshooting

PicFacet lives in the menu bar and has no Dock icon. If you can't see or place its icon, work down this list.

## 1. Is PicFacet running from Applications?

On macOS 27, the menu bar and menu bar managers such as **Bartender** only handle an app's icon properly when the app runs from **/Applications**. Run from anywhere else (Downloads, a build folder), the icon may be drawn off-screen, never show, or jump to the end of the list whenever you move it.

- Users: drag PicFacet into Applications and open it from there.
- Developers: `./script/build_and_run.sh` installs each build to `/Applications/PicFacet.app` and launches that copy. Xcode's Run (⌘R) and the copy under `build/` run from the build folder and have this problem.

Keep only one copy installed. Two apps with the same identity confuse macOS about which one Finder's Quick Actions and the login item use.

## 2. Is it allowed in the menu bar?

**System Settings → Menu Bar → Allow in the Menu Bar**: PicFacet must be switched on.

## 3. Is a menu bar manager hiding it?

In Bartender, check whether PicFacet sits under **Hidden Items** or **Always Hidden**, and drag it to **Shown Items**. Bartender's **Missing Items** link lists the macOS 27 cases it can't control (the Applications rule above is the first one).

## 4. Is the menu bar full?

Without a manager, macOS hides icons that don't fit. Hold ⌘ and drag other icons out, or drag PicFacet further left.

## Still stuck?

Double-click PicFacet in Applications while it's running: it opens the Batch window, and Settings is one click away from there (gear in the bottom bar).

## How placement works (for developers)

- The status item has a fixed `autosaveName` (`PicFacetStatusItem`) so its position can be remembered. Don't change it, or everyone's saved position is lost.
- On macOS 27 the system stores menu bar positions itself; nothing is written to PicFacet's own defaults.
- A force-quit can skip saving; quit from the menu (**Quit PicFacet**) when testing placement.
