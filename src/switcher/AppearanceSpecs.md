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
sizing and is capped at 240pt or 25% of the row, whichever is smaller. It can grow during a switcher session but does not
shrink when filtering; the next session measures afresh. Names use leading
alignment by default and truncate long names without hover tooltips.
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

## Local Titles hover treatment

Titles rows retain the hover background without an outline. Keyboard selection remains solid. Other appearance styles retain their existing border. The additional control for selecting on hover changes selection behavior, not hover feedback.

Borderless Titles hover uses the system control accent at 26% opacity, or 34% with Increase Contrast, retaining the stronger solid selected row. These are local appearance choices, not asserted WCAG contrast ratios.

## Local Safari icon refresh

The personal Titles provider observes atomic snapshot writes through their parent
folder and updates only existing Safari icon layers while the switcher is active.
It must not change selection, scroll, layout or request window screenshots. Reads
that overlap file events schedule a follow-up. A one-shot deadline restores native
icons when the existing snapshot freshness limit expires. Identity matching and
private/ambiguous-window fallbacks are unchanged. The paired companion publishes
independent window results; a slow website must not block an already-ready icon.

The dotfiles `test_live_provider.py` compiles this provider against isolated storage
and UI stand-ins to exercise file replacement, expiration and session preservation.

## Local selected icon separation

Only a selected Titles row may replace its icon shadow with a compact neutral
halo. Both native and site icons qualify when at least 60% of their opaque
silhouette samples have less than 1.5:1 luminance contrast against the actual
system selection background. White is used for dark backgrounds, black for
light ones. Increase Contrast uses a stronger, tighter halo. Unselected and
contrasting icons keep the existing shadow. Artwork and the companion glint are
not modified. This is a supplementary local affordance, not a claim of WCAG
compliance or Apple's prescribed icon styling.

Sampling uses a 16px image off the main thread, once per image change in a recycled
tile. Cycling reuses those results. Delayed results cannot modify a tile that has
received a different image. Live provider updates must use updateDisplayedAppIcon.

Titles also gains a larger screen-bounded reading area, with the content-width
allowance capped at 1400pt. The app column reserves at most a quarter of the row;
most width remains available for single-line window titles. Full titles remain available to accessibility; app-name alignment preferences
remain unchanged.

Primary guidance: [Apple Color](https://developer.apple.com/design/human-interface-guidelines/color)
recommends sufficient contrast and avoiding overlapping similar colors;
[W3C non-text contrast](https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html)
distinguishes necessary graphical information from redundant text-labelled icons.
Neither prescribes a glow. The 1.5 threshold is a narrowly scoped visual heuristic,
not the standard's 3:1 requirement.

## Content-fitted Titles width

Measure the visible rows after automatic font sizing, including native title-cell
width, shared app-name column, icons, status indicators and padding. Fit the panel
to the longest row with a configurable minimum (300pt by default), bounded by the screen/readability
maximum. Recompute on every content layout so closing or renaming the longest
window can shrink the open panel. Selection changes alone do not change its width.
App-name measurement can shrink outside search; search retains its existing column
stability. App names remain capped to 25% of the fitted row and 240pt.

Design reference: [Apple layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout).
The numeric bounds are local design choices, not Apple-prescribed constants.

### Live resizing without spinner jitter

Keep a small spare width of max(24pt, twice the title font point size). Retain the
current session width while content still fits and unused room is at most twice
that allowance. Grow immediately when required content exceeds the current width;
shrink when materially less space is required. Clamp to screen limits even if the
previous width was larger. Reset this width history each summon. Titles themselves
continue updating immediately. This hysteresis is a local usability choice, not
an Apple-prescribed timing or spacing rule.

### Titles row width must equal fitted content width

Titles use the entire fitted row, not the thumbnail layout's 90% row fraction.
Applying that fraction after measuring removes text space and falsely truncates
otherwise fitting titles. The panel's default maximum is 90% of the visible screen width,
including outer panel padding. Text can still truncate at that physical limit.


### Titles width controls

Appearance > Customize exposes native Minimum width and Maximum width sliders
when Titles is selected. Minimum content width ranges from 240 to 600pt (default
300); maximum panel width ranges from 50 to 95% of the visible screen (default 90%).
Descriptions distinguish content points from screen percentage. Controls are
keyboard-accessible and searchable. Preferences persist and export/import through
the existing settings system. Imported out-of-range values are clamped on read.
On small screens the maximum always wins over the minimum and spare room. The
existing live growth/shrink hysteresis remains; these controls do not force a
fixed width. Other styles retain their existing layout.

## Switcher help without hover popups

Switcher titles, app names and status indicators do not install mouse-over
tooltips. Accessibility labels/help remain available, including full titles.
Truncated titles no longer expand in a hover popup. Settings help is unchanged.
