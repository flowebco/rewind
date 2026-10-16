---
name: Pulp Iran
description: Persian industrial guidance for pulp production lines and project evaluation.
colors:
  accent: "#e75a08"
  accent-deep: "#c95e00"
  background: "#e5edf5"
  text-primary: "#2d3748"
  text-secondary: "#5b6b80"
  shadow-light: "rgba(255, 255, 255, 0.9)"
  shadow-dark: "rgba(95, 157, 231, 0.45)"
typography:
  display:
    fontFamily: "Vazirmatn Variable, system-ui, sans-serif"
    fontSize: "clamp(2.4rem, 3.4rem, 4.7rem)"
    fontWeight: 800
    lineHeight: 1.28
  body:
    fontFamily: "Vazirmatn Variable, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.9
  label:
    fontFamily: "Vazirmatn Variable, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 600
rounded:
  xs: "8px"
  sm: "10px"
  compact: "12px"
  control: "14px"
  control-wide: "15px"
  md: "16px"
  nav: "18px"
  cta: "19px"
  card: "20px"
  image: "22px"
  lg: "24px"
  nav-pill: "30px"
  capsule: "40px"
spacing:
  sm: "0.5rem"
  md: "1rem"
  lg: "1.5rem"
  xl: "2rem"
components:
  button-primary:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.md}"
    padding: "0.8rem 1.6rem"
  article-card:
    backgroundColor: "{colors.background}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.lg}"
    padding: "1rem 1.1rem 1.1rem"
---

# Design System: Pulp Iran

## Overview

**Creative North Star: "راهنمای مهندسیِ لمسی"**

Pulp Iran presents industrial production knowledge through a tactile, calm interface. Its Persian right-to-left layout, locally hosted Vazirmatn, blue-gray ground, orange signal color, and paired neumorphic shadows connect the editorial pages to the company site without making the reading surface feel like a control panel.

Use the raised and inset surfaces to clarify interaction and hierarchy. Keep article prose quiet and readable; reserve the stronger dimensional treatment for navigation, featured content, controls, and compact summary groups. Sample articles and archive images must be identified honestly and must not imply an executed project, named author, capacity, or performance claim.

**Key Characteristics:**
- Persian-first, right-to-left composition.
- Soft raised and inset surfaces over one shared ground.
- Orange used as a signal, never as small text on pale surfaces.

## Colors

The palette is a cool blue-gray industrial ground with dark slate text and a restrained orange signal.

### Primary
- **Signal Orange** (`#e75a08`): Brand emphasis, large display accents, and the rotating CTA ring.
- **Deep Orange** (`#c95e00`): Large accent headings and icon accents. At approximately 3.5:1 against the site ground, do not use it for small text.

### Neutral
- **Blue-Gray Ground** (`#e5edf5`): Shared page and raised-component surface.
- **Dark Slate** (`#2d3748`): Primary body and control text; the high-contrast default on light surfaces.
- **Blue Slate** (`#5b6b80`): Secondary copy and supporting labels.
- **Light Shadow** (`rgba(255, 255, 255, 0.9)`): Upper-left component highlight.
- **Blue Shadow** (`rgba(95, 157, 231, 0.45)`): Lower-right component depth.

## Typography

**Display Font:** Vazirmatn Variable (with `system-ui`, sans-serif fallback)
**Body Font:** Vazirmatn Variable (with `system-ui`, sans-serif fallback)
**Label Font:** Vazirmatn Variable

**Character:** Clear Persian forms with weight-led hierarchy. Keep body copy comfortable and regular; use weight 700–800 to establish titles, section openers, and primary actions.

### Hierarchy
- **Display** (800, responsive `rem`-bounded clamp, 1.28–1.5 line-height): Page-level hero headings.
- **Headline** (800, approximately 1.55–2.05rem, 1.6–1.75 line-height): Featured article titles.
- **Title** (700–800, approximately 1.1–1.35rem): Article-card and section headings.
- **Body** (400, 1rem, 1.9–2 line-height): Supporting and article text; keep measures near 60–75ch where the layout allows.
- **Label** (600–800, approximately 0.75–0.9rem): Navigation, metadata, and compact control labels; do not go below 11px for functional text.

## Layout

Use a centered content width capped near 1120px with generous vertical section spacing. The blog index pairs a flexible reading column with a 250px topic rail on wide screens; below 700px, stack the topic selector above the featured content and use one card column. At narrow widths, use viewport-aware side margins so the shell remains inside the visible client area when classic scrollbars are present. Keep article text to a readable measure and preserve normal document scrolling.

## Elevation & Depth

Depth comes from paired soft shadows, not black or sharp edges. A raised surface uses a light upper-left highlight and blue lower-right shadow; pressed states reverse that relationship with inset shadows. Keep shadows consistent with the shared tokens rather than inventing one-off elevations.

### Shadow Vocabulary
- **Raised** (`var(--raised)`): Navigation, controls, cards, and shared-ground surfaces.
- **Hero** (`var(--hero)`): High-emphasis featured surface and hover elevation.
- **Subtle** (`var(--subtle)`): Icon wells and small tactile details.
- **Pressed** (`var(--pressed)`): Active filter states and inset inputs.
- **Pressed Deep** (`var(--pressed-deep)`): Strongly recessed surfaces where already used by the homepage.

## Shapes

Components sit on the same `--bg` surface. Use `--radius: 24px` for major panels; 12–16px for controls and icon wells. Add translucent white borders between 0.3 and 0.5 opacity where they support the soft edge. Avoid hard outlines and black shadows.

## Components

### Buttons
- **Shape:** Rounded, shared-ground surfaces (16px for editorial CTAs).
- **Primary:** Dark slate text over `--bg`, with `var(--raised)` at rest.
- **Hover / Focus:** Soft lift and a visible accent focus outline. The featured article CTA uses the homepage's rotating conic-gradient ring; honor reduced motion.
- **Active:** Use `var(--pressed)` where the control represents a selected or pressed state.

### Cards / Containers
- **Corner Style:** 16–24px, according to emphasis.
- **Background:** The shared `--bg`, optionally with a low-contrast white-to-ground gradient.
- **Shadow Strategy:** `var(--hero)` for featured content; `var(--raised)` for repeated article cards.
- **Border:** A translucent white edge around 0.4 opacity.
- **Internal Padding:** About 1rem for compact cards and 1.2–1.3rem for featured content.

### Inputs / Fields
- **Style:** Shared-ground field with a 16px radius and `var(--pressed)` inset shadow.
- **Focus:** Keep the global high-contrast `:focus-visible` outline; do not remove browser focus indication.
- **Search:** Filter article cards live and compose with the selected category; announce the result count and a recoverable empty state.

### Navigation
- **Style:** Compact raised masthead, Persian RTL links, and a softly highlighted current page.
- **Filters:** Topic controls use raised cards at rest, `var(--pressed)` when active, and 40px icon wells with `var(--subtle)`. Provide a native select at mobile widths.

### Blog Hero
- Use a two-part page title, short explanatory copy, labeled search input, and a compact statbar. Counts must describe the visible sample content and never imply supplied author identities.

## Do's and Don'ts

- Do use the existing color, shadow, radius, motion, and font tokens from `css/styles.css`.
- Do label hypothetical editorial content and archive imagery so readers do not mistake them for project proof.
- Do use `--text-primary` for small text on pale surfaces; use orange for large text, icons, borders, and decorative emphasis.
- Do keep scroll-driven reveals progressive, with content visible by default when unsupported and no animation under reduced motion.
- Don't use black or hard-offset shadows, unrelated card backgrounds, or sharp borders.
- Don't invent author names, article dates, production capacity, customer references, or performance claims.
- Don't use viewport-width-scaled typography or let RTL content extend beneath the scrollbar gutter.