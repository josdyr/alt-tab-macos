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

## Local Titles selection preference

Titles style uses `selectedContentBackgroundColor` and
`alternateSelectedControlTextColor` for a solid selected row without a border.
Other styles retain their selection fills and borders. Hover remains distinct.
Title search-match foreground/background pairs remain intact; selection recoloring
does not recompute title truncation. Recycled rows restore their unselected color.

Review light/dark appearances, selected and unselected rows, search matches, status
symbols, and style changes. Row highlights use a continuous corner curve with the
existing size-dependent radius. Outer panel dimensions and clipping are unchanged;
container-relative corner migration requires separate multi-style testing.

## Local app identity column

Titles style shows app name, icon, and window title in separate columns. The app
name column is measured from displayed windows on each layout and capped at 140pt.
It aligns toward the icon and truncates long names with a full-name tooltip.
Selected names follow the title selection color. In right-to-left layout the
column is mirrored. The `localAppNameColumn` Boolean defaults to enabled when
absent; false restores the prior layout after relaunch. No browser integration
is included in this patch, and no upstream PR should include the personal layout.

Window title search ranges are kept separate from app-name text. Validate changing
selection, long app names, long titles, search, mirrored layout and style changes.
The initial light Titles view was visually checked with Safari, Ghostty and Device
Hub. Mirrored layout, dark appearance and search remain unverified visually.
