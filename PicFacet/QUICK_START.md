# PicFacet - Quick Start Guide

## ✅ What's Built

Your PicFacet app now has a complete, modern UI with:

1. **Liquid Glass Design System** (future-ready for macOS 26+)
2. **Settings Window** with user defaults
3. **Batch Processor** with drag & drop, thumbnails, and live progress
4. **Menu Bar Integration** for easy access

---

## 🚀 How to Use

### **Menu Bar**
Your app lives in the menu bar with these options:

```
📷 PicFacet
├─ Batch Processor…      ⌘B  ← Drag & drop batch processing
├─ ─────────────────
├─ Settings…             ⌘,  ← Configure defaults
├─ How to enable...          ← Onboarding guide
├─ ─────────────────
└─ Quit PicFacet         ⌘Q
```

### **1. Configure Defaults** (First Time Setup)

1. Click menu bar icon → **Settings…**
2. Set your defaults:
   - **Default Format**: JPEG, PNG, HEIC, WebP, etc.
   - **Default Resize**: 10%, 25%, 50%, 75%, 90%
   - **Default DPI**: 72, 96, 150, 300, etc.
3. Configure processing options:
   - Overwrite source files
   - Keep only if smaller
   - Delete original after convert
   - Proportional resize
4. Close settings

### **2. Batch Process Images** (Daily Use)

1. Click menu bar icon → **Batch Processor…**
2. **Drag images** from Finder into the window
3. See **thumbnails** appear with file sizes
4. Select **operation** from dropdown (uses your defaults!)
5. Click **Start Processing**
6. Watch **live progress bar**
7. Get completion alert
8. Done! Files cleared, ready for next batch

---

## 📋 User Workflows

### **Quick Convert**
```
Menu Bar → Batch Processor
Drag 10 images
Operation auto-selected (your default: JPEG)
Click Start
Done in seconds
```

### **Resize for Web**
```
Menu Bar → Batch Processor
Drag images
Choose "Resize to 50%"
Click Start
Done
```

### **Change DPI for Print**
```
Menu Bar → Batch Processor
Drag images
Choose "Set DPI to 300"
Click Start
Done
```

---

## 🎨 Design Features

### **Empty State**
Beautiful drop zone with:
- Large photo icon
- "Drop Images Here" message
- "Select Files…" button
- Dashed border that highlights on drag

### **File List State**
Clean list with:
- 40x40 thumbnails (aspect-ratio preserved)
- Filename and file size
- "Clear" button to remove all
- Badge showing file count

### **Processing State**
- Live progress bar (gradient blue)
- "X of Y" counter
- Disabled controls during processing
- Completion alert with success/failure counts

### **Design Tokens**
```swift
Canvas:      #F9F9FB (light neutral)
Surface:     #FFFFFF (cards)
Primary:     #0058BC → #0070EB (blue gradient)
Text:        #1A1C1D (primary)
Text Subtle: #5E6272 (secondary)
```

---

## 🔧 Technical Details

### **File Structure**
```
PicFacet/
├── PicFacetDesign.swift      ← Design system
├── MenuBarController.swift   ← Menu bar integration
├── SettingsView.swift        ← Settings window
├── ChooserWindow.swift       ← Quick action picker
├── OnboardingWindow.swift    ← First-run guide
└── PicFacetCore/
    ├── ProgressWindow.swift  ← Batch processor UI
    ├── ImageProcessor.swift  ← Processing engine
    ├── PicFacetSettings.swift ← Settings storage
    └── ...
```

### **Settings Storage**
- Stored in **App Group** shared UserDefaults
- Works across app and extensions
- Persists between launches

### **Processing**
- **4 concurrent operations** (multi-threaded)
- Security-scoped resource handling
- Progress callbacks on main thread
- Error handling with detailed alerts

---

## 🎯 Design Philosophy

### **Fast & Simple**
- No keyboard navigation needed
- No history to manage
- Drag & drop for speed
- Defaults pre-selected
- Auto-clear after completion

### **Beautiful & Modern**
- "Ethereal Workspace" design language
- Tonal layering (white-on-white)
- Precision blue accents
- Ghost borders
- Smooth animations
- Future: Liquid Glass on macOS 26+

### **Professional**
- Clean visual hierarchy
- Consistent spacing
- Proper typography
- Thoughtful states (empty, loading, complete)
- Error handling

---

## 🐛 Troubleshooting

### **"Cannot find ProgressWindowController"**
✅ **Fixed!** Now using `public` visibility and `import PicFacetCore`

### **Thumbnails not loading**
- Check file permissions
- Ensure files are valid images
- Placeholder icon shown if thumbnail fails

### **Processing fails**
- Check sandbox permissions
- Verify file access (security-scoped resources)
- See error details in completion alert

---

## 📦 What's Included

✅ Drag & drop batch processor  
✅ Live progress tracking  
✅ Thumbnail list view  
✅ Settings with defaults  
✅ Menu bar integration  
✅ Design system (Liquid Glass ready)  
✅ Empty states  
✅ Error handling  
✅ Completion alerts  
✅ Auto-clear after processing  

---

## 🚀 Next Steps (Optional)

Want to enhance further?

1. **Add operation customization**
   - Let users change format/resize/DPI inline
   - Show pickers based on selected operation

2. **Add "Reveal in Finder"**
   - Show processed files after completion
   - Open output folder

3. **Add window persistence**
   - Remember window position
   - Keep processor window visible while working

4. **Add quick actions integration**
   - Pre-fill batch processor from Finder
   - Right-click → Send to Batch Processor

---

**Your app is ready to ship! 🎉**

Simple, fast, beautiful batch image processing from anywhere on your Mac.
