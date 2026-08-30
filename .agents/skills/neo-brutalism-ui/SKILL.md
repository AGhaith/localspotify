---
name: neo-brutalism-ui
description: >-
  Expert guidelines and design tokens for building high-impact Neo-Brutalism user interfaces.
  Use when designing or modifying UI components, layouts, typography, shadows, and color palettes
  with bold borders, hard offset shadows, vibrant pop colors, and tactile micro-interactions.
---

# Neo-Brutalism UI Design System Guide

Neo-Brutalism (also known as Neubrutalism) combines brutalist raw simplicity with modern typography, playful vibrant colors, and polished micro-interactions.

## 🎨 Core Visual Tenets

1. **High-Contrast Bold Outlines & Borders**:
   - Every major card, button, modal, badge, and input has a distinct solid border (typically `2px solid #000000` in light mode, or `2px solid rgba(255,255,255,0.2)` / `2px solid #000000` with high-contrast surfaces in dark mode).
   - Crisp border radii: slightly rounded corners (`8px` to `16px`) to balance brutalism with modern ergonomics.

2. **Hard Offset Box Shadows (Zero Blur)**:
   - Shadows have **0px blur radius** and a hard directional offset:
     - Standard Cards: `box-shadow: 4px 4px 0px #000000;`
     - Large Hero Elements: `box-shadow: 6px 6px 0px #000000;`
     - Small Buttons & Badges: `box-shadow: 2px 2px 0px #000000;`
     - Dark mode neon accents: `box-shadow: 4px 4px 0px var(--accent);`

3. **Tactile Button Press Interactions**:
   - On `:hover`: subtle color shift or slight hover lift (`transform: translate(-1px, -1px); box-shadow: 5px 5px 0px #000;`).
   - On `:active`: crisp tactile depression (`transform: translate(2px, 2px); box-shadow: 1px 1px 0px #000;`).

4. **Curated High-Energy Color Palette**:
   - **Backgrounds**: Dark charcoal/slate (`#0c0d12`, `#14151f`, `#1e202e`) or warm off-white canvas (`#faf8f5`).
   - **Electric Accents**:
     - 🟢 Acid Lime / Neo Green: `#22c55e` / `#10b981` (Play/Download/Active states)
     - 🟡 Cyber Yellow: `#facc15` / `#fbbf24` (Featured tags, star ratings)
     - 🟣 Electric Violet: `#8b5cf6` / `#7c3aed` (Primary brand accent)
     - 🔴 Neo Coral / Pink: `#ff477e` / `#f43f5e` (Favorites, alerts, destructive actions)
     - 🔵 Cyber Cyan: `#06b6d4` / `#38bdf8` (Informational pills, badges)

5. **Geometric Typography with Personality**:
   - Primary: **Plus Jakarta Sans**, **Space Grotesk**, or **Syne**.
   - Bold, tight tracking headers (`letter-spacing: -0.02em; font-weight: 700 / 800`).
   - Clean, high-legibility body text with crisp contrast.
