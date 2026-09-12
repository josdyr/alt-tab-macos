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
name column uses the text field cell size, including padding, after automatic font
sizing and is capped at 140pt. It can grow during a switcher session but does not
shrink when filtering; the next session measures afresh. Names use leading
alignment by default and truncate long names with a full-name tooltip.
Appearance > Customize more > Right-align app names enables
`localAppNameTrailingAlignment`, aligning names toward the icon column. This
mirrors to left alignment in right-to-left layouts and applies on the next summon.
The toggle does not alter shared width measurement, filtering or font sizing.
Selected names follow the title selection color. In right-to-left layout the
column is mirrored. The `localAppNameColumn` Boolean defaults to enabled when
absent; false restores the prior layout after relaunch. No browser integration
is included in this patch, and no upstream PR should include the personal layout.

Window title search ranges are kept separate from app-name text. Validate changing
selection, long app names, long titles, search, mirrored layout and style changes.
The initial light Titles view was visually checked with Safari, Ghostty and Device
Hub. Mirrored layout, dark appearance and search remain unverified visually.

## Local Safari site icons

`localSafariSiteIcons` defaults off. With the local companion installed and this
Boolean enabled, Titles can display decoded PNGs from manually captured snapshots.
File reads and decoding run on a utility queue; drawing uses cached images only.
Snapshots older than 60 seconds and future timestamps are rejected. A record must
match exactly one eligible Safari window by exact title and bounds within 2pt;
duplicate records or native matches fall back. Application identity remains in
the separate app-name column. This heuristic is experimental, not a stable native
window identifier. Same-title navigation and profile identity are not established.

The app group is specific to the local signing team and must not enter an upstream
PR. Run `python3 scripts/local-tests/test-safari-icons.py` for eleven checks against
the actual provider with model stubs. Live Safari exported two unambiguous matches
and one usable 64px NRK icon. Rendering in the integrated build needs a fresh capture.


Duplicate Safari title/bounds matches may share an icon only when browser/native
candidate counts agree, browser IDs are unique, every image decodes, and all PNG
payloads are identical. Conflicting or incomplete groups still fall back. This
permits two identical BBC windows without claiming a unique window identity.

## Local Titles hover treatment

Titles rows retain the hover background without an outline. Keyboard selection remains solid. Other appearance styles retain their existing border. The additional control for selecting on hover changes selection behavior, not hover feedback.
