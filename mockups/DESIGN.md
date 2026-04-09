# Design System Specification: The Ethereal Workspace

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Ethereal Workspace."** 

This system moves beyond the utility of standard light modes to create a digital environment that feels like a high-end architectural studio. It rejects the "boxed-in" nature of traditional web grids in favor of **Tonal Architecture**. By utilizing white-on-white layering, sophisticated translucency, and the precise application of macOS-inspired blue accents, the interface achieves a "Light Crystal" effect—appearing both weightless and structurally sound. 

We break the "template" look through:
*   **Intentional Asymmetry:** Using generous, breathing whitespace to guide the eye rather than rigid columns.
*   **Optic Weight:** Balancing large, editorial typography against delicate, high-precision UI controls.
*   **Materiality:** Treating surfaces as layers of frosted glass and fine vellum rather than flat pixels.

## 2. Colors & Surface Logic
The palette is rooted in a spectrum of luminous neutrals, designed to reduce cognitive load while maintaining a premium, "expensive" aesthetic.

### Surface Hierarchy & Nesting
Depth is achieved through a hierarchy of "luminous stacking." Instead of using shadows to indicate every change in function, we use the following tiers:
*   **Base Canvas:** `surface` (#f9f9fb) – The primary background for the entire application.
*   **Recessed Sections:** `surface_container_low` (#f3f3f5) – Used for sidebars or secondary utility areas.
*   **Elevated Content:** `surface_container_lowest` (#ffffff) – Used for the primary content cards or active workspaces to create a "pop" against the canvas.
*   **Active Overlays:** `surface_bright` (#f9f9fb) – Reserved for elements that need to feel physically closer to the user.

### Key Rules
*   **The "No-Line" Rule:** Explicitly prohibit the use of 1px solid borders for sectioning. Structural boundaries must be defined solely by color shifts (e.g., a `#ffffff` card sitting on a `#f9f9fb` canvas). 
*   **The "Glass & Gradient" Rule:** For floating elements (menus, tooltips), use a semi-transparent `surface` with a `backdrop-blur` of 20px–40px. 
*   **Signature Textures:** Main Call-to-Actions (CTAs) should utilize a subtle linear gradient from `primary` (#0058bc) to `primary_container` (#0070eb). This mimics the way light hits a physical crystal edge.

## 3. Typography
We use **Inter** exclusively to lean into its neo-grotesque, high-legibility characteristics. The goal is an "Editorial Tech" feel.

*   **Display & Headlines:** Use `display-lg` and `headline-lg` with a slight negative letter-spacing (-0.02em) to create an authoritative, premium look. Headlines should be treated as "Objects" within the layout, often placed with intentional asymmetry.
*   **Body & Labels:** `body-md` is our workhorse. We prioritize line height (1.5x) to ensure the "Light Crystal" airiness persists even in dense information.
*   **Visual Soul:** High-contrast scale jumps (e.g., a `label-sm` placed near a `display-md`) create a sense of bespoke design common in luxury editorial spreads.

## 4. Elevation & Depth
In this system, depth is a feeling, not a feature. We move away from the "Dark Age" of heavy drop shadows.

*   **Tonal Layering:** Most hierarchy is solved by placing a "Lowest" tier (pure white) container on a "Low" tier (light grey) background.
*   **Ambient Shadows:** When an element must float (like a modal), use a "Whisper Shadow":
    *   **Color:** `on_surface` (#1a1c1d) at 4% to 6% opacity.
    *   **Blur:** 30px to 60px spread.
    *   **Logic:** The shadow must feel like ambient light occlusion, not a direct light source projection.
*   **The "Ghost Border" Fallback:** If a container lacks sufficient contrast against its background, use a `outline_variant` (#c1c6d7) at **15% opacity**. This creates a suggestion of an edge without introducing a hard line.

## 5. Components

### Buttons
*   **Primary:** A gradient of `primary` to `primary_container`. Corner radius: `full`. No border. Text: `on_primary` (#ffffff).
*   **Secondary:** `surface_container_high` (#e8e8ea) background. Text: `on_surface`. Focuses on tactile integration.
*   **Tertiary:** Ghost style. No background; uses `primary` text. Becomes `surface_container_low` on hover.

### Cards & Containers
*   **The Rule of Zero:** Cards must never have dividers. Use `body-sm` labels or increased vertical padding (from the `xl` spacing scale) to separate groups of information.
*   **Shape:** Apply `lg` (1rem) or `xl` (1.5rem) roundedness to all primary containers to soften the "tech" feel.

### Input Fields
*   **Surface:** `surface_container_lowest` (#ffffff).
*   **Border:** A "Ghost Border" using `outline_variant` at 20% opacity. 
*   **Focus State:** The border opacity increases to 100% using the `primary` blue, accompanied by a soft blue outer glow (4px blur, 10% opacity).

### Glass Sidebars
*   Sidebars should utilize `surface` with 80% opacity and a heavy `backdrop-blur`. This allows content to scroll "under" the sidebar, creating a sense of deep layered space.

### Selection Chips
*   **Unselected:** `surface_container_high` with `on_surface_variant` text.
*   **Selected:** `primary` background with `on_primary` text. Use `full` roundedness to mimic physical pills.

## 6. Do's and Don'ts

### Do
*   **DO** use whitespace as a functional tool. If an interface feels "crowded," increase the padding rather than adding a border.
*   **DO** use the `primary` blue (#007AFF) as a precision instrument—only for interactive elements or critical indicators.
*   **DO** lean into "White on White" design. Trust the subtle shifts between `#ffffff` and `#f9f9fb`.

### Don'ts
*   **DON'T** use pure black (#000000) for text. Use `on_surface` (#1a1c1d) to maintain the soft, high-end feel.
*   **DON'T** use 1px dividers to separate list items. Use 12px–16px of vertical space or a subtle `surface_container` background change on hover.
*   **DON'T** use standard Material Design elevation shadows. They are too aggressive for the "Light Crystal" aesthetic. Stick to Tonal Layering.