# Safari site icon provider

- Only enabled Titles sessions replace Safari application icons.
- Snapshots expire after 60 seconds. Expiration removes icons even while the switcher remains open.
- A directory observer handles atomic snapshot replacement; pending refreshes coalesce during a load.
- Identity requires an exact nonempty title and bounds within two points. Hidden, minimized, fullscreen, tabbed, windowless and non-Safari windows are ineligible.
- Ambiguous candidates are accepted only when every matching record has an identical image and the window counts agree. No remembered match overrides current identity evidence.
- Live replacement passes through the same tile icon presentation method as initial rendering.
- Unified logging uses subsystem `com.josdyr.alttab-site-icons`, category `provider`. Fixed reason codes identify absent/expired snapshots, decode failures, title/bounds mismatch and ambiguous candidates. Each reason is limited to once per ten seconds. Logs contain no titles, URLs, image data or window identifiers.
- The companion exports separate bounded collection diagnostics. A missing icon may be a safe fallback, not a rendering failure. Collection logs and provider logs distinguish those cases.

## Navigation title transitions

After a unique exact title/bounds match, bind the native Window object weakly to
its Safari window ID. A title mismatch may use that record only while the fresh
snapshot still contains it and both native and browser geometry are unique.
Use the current record image, never a saved previous image. Missing records,
expired snapshots, closed/hidden windows, changed bounds and ambiguous geometry
must not gain a title-independent match. Duplicate-title image equivalence does
not create a binding. Provider logs `bound-window-title-transition` without titles.

## Stable image presentation

Identical PNG records retain their decoded CGImage identity between snapshots.
A replacement icon and its sampled edge treatment are applied in one transaction
with implicit actions disabled. Edge samples must exist before the replacement
is displayed; no temporary empty-sample shadow state is shown.
