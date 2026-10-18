---
name: Pulp Iran
description: Persian industrial guidance for pulp production lines and project evaluation.
colors:
  accent: "#e75a08"
  accent-deep: "#c95e00"
  accent-ink: "#9c4800"
  background: "#e5edf5"
  text-primary: "#2d3748"
  text-secondary: "#5b6b80"
  shadow-light: "rgba(255, 255, 255, 0.9)"
  shadow-dark: "rgba(95, 157, 231, 0.45)"
typography:
  display:
    fontFamily: "Vazirmatn Variable, system-ui, sans-serif"
    fontSize: "clamp(2.5rem, 4vw, 3.75rem)"
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

Pulp Iran presents industrial production knowledge through a tactile, calm interface. Its Persian right-to-left layout, locally hosted Vazirmatn variable webfont, blue-gray ground, orange signal color, and paired neumorphic shadows connect the editorial pages to the company site without making the reading surface feel like a control panel.

Use the raised and inset surfaces to clarify interaction and hierarchy. Keep article prose quiet and readable; reserve the stronger dimensional treatment for navigation, featured content, controls, and compact summary groups. Sample articles and archive images must be identified honestly and must not imply an executed project, named author, capacity, or performance claim.

**Key Characteristics:**
- Persian-first, right-to-left composition.
- Soft raised and inset surfaces over one shared ground.
- Orange used as a signal, never as small text on pale surfaces.

## Colors

The palette is a cool blue-gray industrial ground with dark slate text and a restrained orange signal.

### Primary
- **Signal Orange** (`#e75a08`): Brand emphasis, large display accents, and the rotating CTA ring. Measures 3.03:1 against the ground, so it is decoration and large text only.
- **Deep Orange** (`#c95e00`, `--accent-darken`): Large accent headings and icon accents. Measures 3.49:1 against the ground, which clears the 3:1 bar for large text (24px+, or 18.66px bold) and for non-text elements, and fails the 4.5:1 bar below that. Do not use it for small text.
- **Accent Ink** (`#9c4800`, `--accent-ink`): The orange to use for **small** accent text — navigation, labels, chips, kickers, hover states on link-sized type. Measures 5.32:1 against the ground, clearing AA with margin. Chosen over `#a94e00` (4.70:1) for headroom.

`--accent-ink` is a palette addition, not drift: it exists because `--accent-darken` cannot legally be used at label sizes, and before it was introduced the code used it there anyway in fourteen places.

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

One `@font-face` in `css/styles.css` serves all three, from
`fonts/Vazirmatn-Variable.woff2` with `font-weight: 100 900` on the upstream
`wght` axis. Do not reintroduce per-weight static files: the family name says
"Variable", and five static faces sharing it gave every weight between the five
a synthesized or nearest-match rendering while costing 255 KB instead of 108 KB.

**Character:** Clear Persian forms with weight-led hierarchy. Keep body copy comfortable and regular; use weight 700–800 to establish titles, section openers, and primary actions.

### Hierarchy

Set sizes with the `--text-*` tokens in `css/styles.css`, never with literals. The
ramp is 13 steps and every `font-size` in both stylesheets resolves through it, so
a new literal is a new off-ramp size by definition.

| Token | Size | px | Role |
|---|---|---|---|
| `--text-xs` | 0.75rem | 12 | Captions, kickers, stat labels. **The floor** — DESIGN.md's 11px minimum for functional text, with margin. |
| `--text-sm` | 0.8125rem | 13 | Dense metadata, card copy. |
| `--text-md` | 0.875rem | 14 | Labels, navigation, buttons. |
| `--text-lg` | 0.9375rem | 15 | Secondary body, excerpts. |
| `--text-base` | 1rem | 16 | Body copy. |
| `--text-lead` | 1.125rem | 18 | Lead-ins, emphasised body. |
| `--text-title-sm` | 1.25rem | 20 | Small section titles. |
| `--text-title` | 1.375rem | 22 | Article-card and section headings. |
| `--text-title-lg` | 1.5rem | 24 | Featured titles. |
| `--text-headline-sm` | 1.75rem | 28 | Page sub-headlines. |
| `--text-headline` | 2rem | 32 | Page headlines. |
| `--text-headline-lg` | 2.25rem | 36 | Mobile display maxima. |
| `--text-display-xs` | 2.5rem | 40 | Smallest desktop display step. |

Below `1rem` the step is `0.0625rem` (1px) because the design genuinely uses
1px-level distinctions there; above it the steps widen. Hero and landing display
sizes use `clamp()` whose endpoints should land on ramp steps where practical.

- **Display** (800, `clamp()` bounded by ramp endpoints, 1.28–1.5 line-height): page-level hero headings.
- **Headline** (800, `--text-headline-sm` … `--text-headline-lg`, 1.6–1.75 line-height): featured article titles.
- **Title** (700–800, `--text-lead` … `--text-title`): article-card and section headings.
- **Body** (400, `--text-base`, 1.9–2 line-height): supporting and article text; keep measures near 60–75ch where the layout allows.
- **Label** (600–800, `--text-xs` … `--text-md`): navigation, metadata, and compact control labels; `--text-xs` is the floor, do not go below it.

A `clamp()` middle term must be a **relative** length. `clamp(1.55rem, 1.85rem,
2.05rem)` and `clamp(2.4rem, 3.4rem, 4.7rem)` both collapsed to a fixed value and
were never fluid; both are fixed. Do not write one whose middle term is a `rem`
literal.

## Spacing

Set every `gap`, `margin` and `padding` with the `--sp-*` tokens in
`css/styles.css`. They step by `0.125rem` (2px) from `--sp-1` up to the largest
value the design actually uses, and only used steps are declared — there are no
dead tokens.

Before this the two stylesheets carried **43 distinct rem spacing values across
203 declarations** (`0.15`, `0.38`, `0.62`, `0.72`, `1.05`, `1.15`, `1.3`, `2.3`,
`3.4` …) with no base unit behind them, which is why the vertical rhythm read as
accidental. Snapping them was measured before it was applied:

| grid | moved ≤1px | moved >1px | worst |
|---|---|---|---|
| 4px (`0.25rem`) | 143 | **60** | 1.9px |
| **2px (`0.125rem`)** | **203** | **0** | **0.8px** |

So the step is 2px, not the 4px a spacing scale usually starts from. A 4px grid
would have *changed* the rhythm instead of naming it; 2px preserves every value
to within 0.8px. If you add spacing, add it on this grid.

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

### Glass Button (`.glass-btn`)

A "wet glass" control in `css/styles.css`, used for the consultation CTA in the
blog rail. Translucent box, blurred inner rim and corner sheen pushed through a
high-contrast filter, which is what makes the edge read as liquid.

Three rules keep it inside this system rather than bolted onto it:

- **The contrast filter is confined to `.glass-fx`**, an absolutely positioned
  layer with no text in it. Putting `filter: contrast(3)` on a page-level wrapper
  creates a containing block that silently breaks `position: fixed` and `sticky`
  inside it, and it would run the label's and icon's drop-shadows through
  contrast(3) and turn them into black halos.
- **No black.** The reference used a hard black inner outline and a black drop
  shadow; both are replaced with `--shadow-dark`, the site's own blue, at low
  alpha. Radius is the documented `capsule` step, not `9999px`.
- **Contrast is measured, not assumed.** Label `--text-primary` = 10.14:1 on the
  ground. The white glyph on the `--accent` disc = 3.58:1, which clears the 3:1
  bar for a non-text element. The `:active` colour is `--text-primary`, not pure
  black.

Sizing is fluid: `--glass-w: clamp(15rem, 100%, 17.5rem)`, height
`clamp(3.25rem, 9vw, 3.75rem)` so it never drops below the 48px touch floor, and
a 400px breakpoint where it fills its container. The chevron is the reference's
own path mirrored with `scaleX(-1)`, because this site is RTL and "onward"
points left. Motion honours `prefers-reduced-motion`.

Known limit: `backdrop-filter` has nothing to sample on a flat pale ground, so the
"glass" reads mostly from the blurred rim and sheen. It shows best where the
surface behind it varies — the rail card's white-to-orange gradient, for
instance. Do not expect a frosted-window look over a uniform background.

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