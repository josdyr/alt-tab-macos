# Appearance (window sizing) — Specs

> **Line coverage:** `AppearanceTestable.swift` 79% · _refreshed 2026-05-27 by `/coverage-explore`_

## Summary

Two pure sizing functions in `AppearanceTestable` decide how big the switcher's thumbnails are on a
given display, so the UI feels right from an 11" laptop to a 60" TV. The suite pins their output against
a table of **21 real device models** (laptops, monitors, ultrawides, TVs) with known pixel + physical
dimensions, so a tweak to the formula can't silently regress any class of screen.

- `comfortableWidth(physicalDimension)` → the fraction of the screen the switcher should occupy (smaller
  fraction on bigger/wider screens, separate expectations for horizontal vs vertical use).
- `goodValuesForThumbnailsWidthMinMax(ratio, rowCount)` → the (min, max) thumbnail width for a given
  screen aspect ratio and row count (3, 4, or 5 rows).

## Behavior & edge cases

- Driven entirely by a fixture table: each row is `(model, pixels, physical-mm, expected comfortable
  fractions, [(rowCount, expectedMin, expectedMax)])`. Both tests loop the table and assert with `0.01`
  tolerance, naming the failing model.
- Bigger physical screens get a smaller comfortable fraction (a 60" TV shouldn't show a half-screen
  switcher); ultrawides get distinct horizontal vs vertical fractions.

## Test scenarios

Mirrors `AppearanceTests.swift` 1:1.

- **testGoodValuesForThumbnailsWidthMinMax** — for every model × {3,4,5} rows, the computed (min, max) thumbnail width matches the fixture.
- **testComfortableWidth** — for every model, the comfortable width fraction matches for both horizontal and vertical screen use.
- **testComfortableWidthFallsBackToDefaultWhenPhysicalWidthIsNil** — when the screen's physical dimensions aren't reported, fall back to the 0.9 default rather than the 0.45 floor.
- **testGoodValuesForThumbnailsWidthMinMaxPortrait** — for aspectRatio < 1 (portrait usage), the (min, max) uses the portrait formula and stays within the [0.09, 0.30] clamps.

## macOS 27 glass panel corners

The backing layer of each `NSGlassEffectView` clips to the same continuous corner
radius as the glass. This bounds the rectangular corner artifacts reported in
[#5757](https://github.com/lwouis/alt-tab-macos/issues/5757). Update both radii when
reusing an effect view after a style or size change. The existing window shadow
and glass material remain enabled. macOS 26 and earlier retain their rendering.

Manual verification: repeatedly summon/dismiss Titles and Thumbnails, change
between those styles (23pt and 43pt corners), and change App Icons sizes
(50pt, 55pt, 75pt corners). Inspect all four corners in light and dark appearances,
including against contrasting backgrounds. Check that selection, scrolling and
search remain usable. Recheck on later macOS 27 builds before removing the workaround.
## Selected-window preview corners on macOS 27

The selected-window preview outline follows the native preview panel's effective
container-concentric radius. It uses a continuous layer border and refreshes when
the effective radius or appearance changes. Earlier macOS versions retain the
existing drawn outline. This does not infer an arbitrary source window's silhouette.

Manual regression scenarios:
- On macOS 27, summon with selected-window preview enabled and cycle among normal
  windows. Check that the outer outline follows the preview panel without square
  protrusions and updates after resizing or changing appearance.
- Check fullscreen and custom-shaped source windows, different displays and
  scale factors, and light/dark appearance. These require visual validation.
- On macOS 26 or earlier, compare against an unpatched build to verify unchanged
  outline rendering. Native corner configuration is unavailable on those systems.

The original local candidate was visually checked with Device Hub on macOS 27.
That observation does not establish the broader scenarios above.
## Titles style: app name column, fitted width and selection

### App name column

Customize style > **Show app names in a separate column** (Titles only, off by default) moves each window's app name
into its own column before the icon, so the icon and title columns line up across rows. The row title then shows the
window title only, regardless of **Show titles**. **Right-align app names** aligns names toward their icons; both are
mirrored in right-to-left layouts. The column fits the widest visible app name, capped at 240pt and a quarter of the
screen-bounded row. It is measured with the native text cell (including its padding) after automatic font sizing. It
can grow during a switcher session but never shrinks while searching, so filtering doesn't shift titles.

### Fitted width

The Titles panel fits its widest visible row (title, app name column, icon, status icons and padding) between
**Minimum width** (240 to 600pt, default 300) and **Maximum width** (50 to 95% of the visible screen, default 90%).
The maximum always wins on small screens. Rows use the whole fitted width.

The width is fitted once per summon, before the panel appears, with spare room of max(24pt, twice the font size) so
spinners and counters in titles don't truncate right away. Once the panel is visible its width never changes: title
changes, windows opening or closing, and search filtering don't grow or shrink it, and longer titles truncate instead.
A width change under the pointer is distracting and moves rows the user is aiming at (Apple's layout guidance: avoid
gratuitous layout changes). The only exception is clamping to a smaller maximum, for example after a display change.

Titles are measured with the current font on every layout. With Auto size the font changes between displays; an
unchanged title must not keep the previous display's measurement, or the panel would be too narrow and truncate.

### Selection and hover

The selected Titles row uses the solid system selection color (`selectedContentBackgroundColor`) with the matching
text color for the title, app name and status icons. Hover uses the accent color at 26% opacity (34% with Increase
Contrast) without an outline. Other styles keep their existing highlight.

### Icon separation

When most of a selected icon's silhouette has less than 1.5:1 luminance contrast with the selection color (a blue icon
on a blue selection), the icon gets a tight neutral halo instead of its usual shadow: white on dark selections, black
on light ones, stronger with Increase Contrast. The silhouette is sampled once per icon image at 16x16.

### No hover tooltips in the switcher

Switcher titles, app names and status icons don't show mouse-over tooltips, in every style. While hovering rows to
pick a window, tooltips popped up over neighboring rows and duplicated what the row already shows. The full title and
status descriptions stay available to VoiceOver as accessibility labels and help. Settings tooltips are unchanged.

Manual checks: long and short app names, right-to-left layout, dark mode, Increase Contrast, search filtering, closing
the widest window while open (width must not change), a terminal title with a spinner, and switching between displays of different sizes with Auto size.
