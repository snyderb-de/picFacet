# Menu Bar Icon Troubleshooting

## ❌ Problem: Menu bar icon not showing

## ✅ What Should Happen

When you run the app, you should see:
1. **Photo icon in menu bar** (top right corner)
2. **No Dock icon** (app is `.accessory` mode)
3. **Logs in Console** showing initialization

---

## 🔍 Debugging Steps

### Step 1: Check Console Logs

Open **Console.app** and filter for your app:

1. Open Console.app
2. In the search box, type: `process:PicFacet`
3. Run your app
4. You should see:
   ```
   [AppDelegate] App finished launching
   [AppDelegate] Activation policy set to .accessory
   [AppDelegate] MenuBarController created
   [MenuBar] Menu bar initialized
   [MenuBar] Configuring button...
   ```

### Step 2: Check Process

In **Activity Monitor**:
1. Search for "PicFacet"
2. You should see it running
3. Kind should be "Application"

### Step 3: Check Build Target

In Xcode:
1. Go to your **project settings**
2. Select the **PicFacet target** (not PicFacetCore)
3. Go to **General** tab
4. Check **"Hide from Dock"** is NOT checked (we want `.accessory` mode from code)

---

## 🐛 Common Issues

### Issue 1: App Not Running
**Symptom**: No logs, no menu bar icon
**Fix**: Press Cmd+R to actually **run** the app, not just build it

### Issue 2: Wrong Target Selected
**Symptom**: Extension runs instead of main app
**Fix**: 
1. Click the scheme dropdown (next to Play button)
2. Select "PicFacet" (not the extension)
3. Run again

### Issue 3: Multiple Instances
**Symptom**: Weird behavior
**Fix**:
1. Quit all PicFacet instances
2. Clean build (Cmd+Shift+K)
3. Run again

### Issue 4: Code Signing
**Symptom**: App crashes on launch
**Fix**: Check the crash logs in Console.app

---

## 🎯 Quick Test

Run this in **Terminal** while your app is running:

```bash
ps aux | grep PicFacet
```

You should see your app process. If not, it's not running.

---

## 🔧 Alternative: Force Menu Bar Icon

If the app is running but no icon appears, try this temporary fix in MenuBarController:

```swift
init() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    // TEMPORARY: Force visible icon
    if let button = statusItem.button {
        button.title = "📷"  // Emoji as fallback
    }
    
    configureButton()
    buildMenu()
    NSLog("[MenuBar] Menu bar initialized")
}
```

If you see the emoji, then the menu bar **is** working, just the icon creation failed.

---

## 📋 Checklist

Before proceeding, verify:

- [ ] You're **running** the app (Cmd+R), not just building
- [ ] The correct **scheme** is selected (PicFacet, not extension)
- [ ] **Console.app** is open and filtered for "PicFacet"
- [ ] **Activity Monitor** shows PicFacet running
- [ ] You've **cleaned** (Cmd+Shift+K) and rebuilt
- [ ] You're looking in the **right menu bar** (top right, not Dock)

---

## 🎨 About the Design

Your app **already has Liquid Glass design** everywhere:
- ✅ ChooserWindow uses PFDesign components
- ✅ ProgressWindow uses ProgressDesign (matching PFDesign)
- ✅ SettingsView uses native Form (System Settings style)
- ✅ OnboardingWindow uses PFDesign components

**All windows are consistent!** The ChooserWindow you're seeing IS using the design system with:
- PFCard (white card with ghost border)
- PFChip (pill-shaped selectors)
- PFPrimaryButtonStyle (gradient blue button)
- PFSectionLabel (uppercase labels)
- Badge with file count
- Thumbnails (as of latest update)

**When macOS 26 releases**, the Liquid Glass effects will automatically activate (via the `#available(macOS 26.0, *)` checks).

---

## 🚀 Next Steps

1. **Find the menu bar icon** - It should be there
2. If still missing, add the emoji test above
3. Share the filtered Console logs if still stuck

The design is already unified and beautiful! You just need to locate that menu bar icon. 🎯
