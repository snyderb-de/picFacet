# PicFacet UI Consistency Guide

## ✅ What's Now Consistent

Your app now has a **unified design language** across all windows!

---

## 🎨 Design System

### **"Ethereal Workspace"**
All windows share:
- ✅ **Tonal layering** (white-on-white)
- ✅ **Precision blue accents** (#0058BC → #0070EB gradient)
- ✅ **Ghost borders** (subtle 15% opacity)
- ✅ **Pill-shaped chips** for selections
- ✅ **Card-based layouts** with PFCard
- ✅ **Liquid Glass ready** (macOS 26+)
- ✅ **Thumbnails** showing image previews

---

## 🪟 Windows Overview

### 1. **Menu Bar** 
**Icon**: Photo + Diamond overlay (custom composition)

**Menu Items**:
```
📷 PicFacet
├─ Batch Processor…      ⌘B
├─ ─────────────────
├─ Settings…             ⌘,
├─ How to enable...
├─ ─────────────────
└─ Quit PicFacet         ⌘Q
```

---

### 2. **ChooserWindow** (Quick Actions)
**Triggered by**: Finder → Right-click image(s) → Quick Actions → "PicFacet…"

**Features**:
- ✅ Thumbnail strip (shows first 5 images)
- ✅ File count badge
- ✅ Format selection chips
- ✅ Resize percentage chips
- ✅ DPI picker
- ✅ Gradient "Start Processing" button
- ✅ Uses your defaults from Settings
- ✅ Completion alerts

**Design**:
```
┌─────────────────────────────┐
│ Converter               [3] │ ← Header with badge
│ 3 images selected           │
├─────────────────────────────┤
│ [🖼️] [🖼️] [🖼️]              │ ← Thumbnails (up to 5)
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ FORMAT SELECTION        │ │
│ │ [JPEG] [PNG] [HEIC]...  │ │ ← Chips
│ │                         │ │
│ │ RESIZE CONTROLS         │ │
│ │ [10%] [25%] [50%]...    │ │ ← Chips
│ │                         │ │
│ │ DPI SETTINGS            │ │
│ │ [72 DPI ▾]              │ │ ← Picker
│ │                         │ │
│ │ [Start Processing]      │ │ ← Gradient button
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

---

### 3. **ProgressWindow** (Batch Processor)
**Triggered by**: Menu Bar → "Batch Processor…"

**Features**:
- ✅ **Empty State**: Drag & drop zone
- ✅ **File List**: Thumbnails + filenames + sizes
- ✅ **Live Progress**: Animated progress bar
- ✅ **Operation Picker**: Dropdown with defaults
- ✅ **Auto-clear**: After completion
- ✅ **Completion Alerts**: Success/failure counts

**Design**:

**Empty State**:
```
┌─────────────────────────────┐
│ Batch Processor             │
├─────────────────────────────┤
│                             │
│       📷                    │
│   Drop Images Here          │
│   Or click below...         │
│                             │
│   [Select Files…]           │
│                             │
└─────────────────────────────┘
```

**With Files**:
```
┌─────────────────────────────┐
│ Batch Processor        [12] │ ← Badge
│ Ready to process            │
├─────────────────────────────┤
│ FILES              [Clear]  │
│ ┌─────────────────────────┐ │
│ │ [🖼️] image1.jpg   2.4MB │ │
│ │ [🖼️] image2.png   1.8MB │ │
│ │ [🖼️] image3.heic  3.1MB │ │
│ └─────────────────────────┘ │
│                             │
│ ┌─────────────────────────┐ │
│ │ OPERATION               │ │
│ │ [Choose Operation ▾]    │ │
│ │ [Start Processing]      │ │
│ └─────────────────────────┘ │
└─────────────────────────────┘
```

**Processing**:
```
┌─────────────────────────────┐
│ Batch Processor        [12] │
│ Processing…                 │ ← Blue text
├─────────────────────────────┤
│ FILES                       │
│ [... file list ...]         │
│                             │
│ Processing images…   7 of 12│ ← Progress
│ ▓▓▓▓▓▓▓░░░░░               │ ← Bar
│                             │
│ [Operation disabled]        │
└─────────────────────────────┘
```

---

### 4. **SettingsView**
**Triggered by**: Menu Bar → "Settings…"

**Features**:
- ✅ App icon + header
- ✅ **Defaults Section**: Format, Resize %, DPI
- ✅ **General Section**: Appearance picker
- ✅ **Processing Section**: Toggles
- ✅ **Resize Section**: Proportional toggle
- ✅ Native Form styling (matches System Settings)

**Design**:
```
┌─────────────────────────────┐
│      📷                      │
│    PicFacet                  │
│ Image processing from...    │
├─────────────────────────────┤
│ ┌─ General ────────────────┐│
│ │ Appearance               ││
│ │ [System|Light|Dark]      ││
│ └──────────────────────────┘│
│                             │
│ ┌─ Defaults ───────────────┐│
│ │ Default format    [JPEG▾]││
│ │ Default resize    [50% ▾]││
│ │ Default DPI       [72  ▾]││
│ └──────────────────────────┘│
│                             │
│ ┌─ Processing ─────────────┐│
│ │ □ Overwrite source       ││
│ │ □ Keep only if smaller   ││
│ │ □ Delete after convert   ││
│ └──────────────────────────┘│
│                             │
│ ┌─ Resize ─────────────────┐│
│ │ ☑ Keep proportions       ││
│ └──────────────────────────┘│
└─────────────────────────────┘
```

---

### 5. **OnboardingWindow**
**Triggered by**: First launch or Menu → "How to enable Quick Actions…"

**Features**:
- ✅ Matches design system
- ✅ Clear instructions
- ✅ "Open System Settings" button
- ✅ "Got it" to dismiss

---

## 🎨 Shared Design Components

All windows use these components from `PicFacetDesign.swift`:

### **PFCard**
```swift
PFCard {
    // Content with 22px padding
    // White background
    // Ghost border
    // Soft shadow
}
```

### **PFChip**
```swift
PFChip(title: "JPEG", isSelected: true) {
    // Handle selection
}
// Pill-shaped
// Interactive hover states
// Gradient when selected
```

### **PFPrimaryButtonStyle**
```swift
Button("Start Processing") { }
    .buttonStyle(PFPrimaryButtonStyle())
// Full-width
// Blue gradient background
// White text
// Shadow
```

### **PFSecondaryButtonStyle**
```swift
Button("Cancel") { }
    .buttonStyle(PFSecondaryButtonStyle())
// Gray background
// Capsule shape
// Hover states
```

### **PFSectionLabel**
```swift
PFSectionLabel(text: "Format Selection")
// Uppercase
// Small
// Letter-spaced
// Gray color
```

### **PFProgressView**
```swift
PFProgressView(current: 7, total: 10)
// Gradient progress bar
// "X of Y" counter
// Description text
```

---

## 🔄 Consistency Checklist

Every window now has:
- ✅ **Same color palette** (canvas, surface, primary blue)
- ✅ **Same typography** (SF Pro with consistent sizes)
- ✅ **Same spacing** (24px outer, 22px card, 14px/18px inner)
- ✅ **Same corner radii** (20px cards, 14px inner elements)
- ✅ **Same animations** (0.12s-0.15s ease-in-out)
- ✅ **Same shadows** (subtle depth)
- ✅ **Thumbnails** (40x40px, rounded corners)
- ✅ **File count badges** (blue pill)
- ✅ **Completion alerts** (success/error messaging)

---

## 🎯 User Experience Flow

### **Quick Actions (ChooserWindow)**
```
Finder → Right-click → Quick Actions → PicFacet…
     ↓
ChooserWindow opens (thumbnails + operation picker)
     ↓
Select operation → Start Processing
     ↓
Alert shows completion
     ↓
Window closes
```

### **Batch Processing (ProgressWindow)**
```
Menu Bar → Batch Processor…
     ↓
ProgressWindow opens (empty state)
     ↓
Drag images OR click "Select Files…"
     ↓
Thumbnails appear in list
     ↓
Choose operation (defaults pre-selected)
     ↓
Start Processing → Live progress bar
     ↓
Alert shows completion
     ↓
Files auto-clear, ready for next batch
```

---

## 🎨 Color Reference

```swift
// Canvas & Surfaces
canvas:       #F9F9FB  // Base background
surfaceLowest:#FFFFFF  // Cards
surfaceLow:   #F3F3F5  // Recessed
surfaceHigh:  #E8E8EA  // Unselected chips

// Text
onSurface:    #1A1C1D  // Primary text
onSurfaceVariant: #5E6272  // Secondary text

// Borders
outlineVariant: #C1C6D7  // Ghost borders

// Primary (Blue)
primary:      #0058BC  // Base blue
primaryBright:#0070EB  // Bright blue
// Gradient: topLeading → bottomTrailing
```

---

## 📐 Spacing Reference

```swift
// Outer padding
windowPadding: 24px

// Card padding
cardPadding: 22px

// Internal spacing
sectionSpacing: 14-18px

// Element spacing
chipSpacing: 8px
thumbnailSpacing: 8px
```

---

## 🔤 Typography Reference

```swift
// Headers
title: 22pt, semibold, -0.4 tracking
subtitle: 12pt, regular

// Section labels
sectionLabel: 10pt, semibold, 1.4 tracking, UPPERCASE

// Chips
chipText: 12pt, semibold

// Buttons
primaryButton: 14pt, semibold
secondaryButton: 13pt, medium

// File info
filename: 12pt, medium
filesize: 10pt, regular
```

---

**Your app now has a consistent, beautiful, professional UI! 🎉**
