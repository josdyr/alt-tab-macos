# Safari site icon provider

- Only enabled Titles sessions replace Safari application icons.
- Snapshots expire after 60 seconds. Expiration removes icons even while the switcher remains open.
- A directory observer handles atomic snapshot replacement; pending refreshes coalesce during a load.
- Identity requires an exact nonempty title and bounds within two points. Hidden, minimized, fullscreen, tabbed, windowless and non-Safari windows are ineligible.
- Ambiguous candidates are accepted only when every matching record has an identical image and the window counts agree. No remembered match overrides current identity evidence.
- Live replacement passes through the same tile icon presentation method as initial rendering.
- Unified logging uses subsystem `com.josdyr.alttab-site-icons`, category `provider`. Fixed reason codes identify absent/expired snapshots, decode failures, title/bounds mismatch and ambiguous candidates. Each reason is limited to once per ten seconds. Logs contain no titles, URLs, image data or window identifiers.
- The companion exports separate bounded collection diagnostics. A missing icon may be a safe fallback, not a rendering failure. Collection logs and provider logs distinguish those cases.
