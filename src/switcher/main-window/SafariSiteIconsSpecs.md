# Safari site icon provider

- Only enabled Titles sessions replace Safari application icons.
- Snapshots expire after 60 seconds for accepting replacement artwork. The last ready image remains available in memory for its previously verified native window.
- A directory observer handles atomic snapshot replacement; pending refreshes coalesce during a load.
- Identity requires an exact nonempty title and bounds within two points. Hidden, minimized, fullscreen, tabbed, windowless and non-Safari windows are ineligible.
- Ambiguous candidates are accepted only when every matching record has an identical image and the window counts agree. Uncertain matches cannot introduce new artwork; previously verified artwork may remain displayed.
- Live replacement passes through the same tile icon presentation method as initial rendering.
- Unified logging uses subsystem `com.josdyr.alttab-site-icons`, category `provider`. Fixed reason codes identify absent/expired snapshots, decode failures, title/bounds mismatch and ambiguous candidates. Each reason is limited to once per ten seconds. Logs contain no titles, URLs, image data or window identifiers.
- The companion exports separate bounded collection diagnostics. A missing icon may be a safe fallback, not a rendering failure. Collection logs and provider logs distinguish those cases.

## Navigation title transitions

After a unique exact title/bounds match, bind the native Window object weakly to
its Safari window ID. A title mismatch may use that record only while the fresh
snapshot still contains it and both native and browser geometry are unique.
Use the current record image when it can be matched. Missing records, expired
snapshots, changed bounds and ambiguous geometry must not introduce new artwork.
They may retain the last ready image for the same live native Window object. Duplicate-title image equivalence does
not create a binding. Provider logs `bound-window-title-transition` without titles.

## Stable image presentation

Identical PNG records retain their decoded CGImage identity between snapshots.
A replacement icon and its sampled edge treatment are applied in one transaction
with implicit actions disabled. Edge samples must exist before the replacement
is displayed; no temporary empty-sample shadow state is shown.

## First summon during navigation

Start snapshot observation with application discovery, and establish exact unique
window bindings on snapshot refresh even while the switcher is closed. Do not
update tile images while inactive. A later URL title can then use the verified
binding without requiring a previous switcher invocation. Unseen windows still
require an exact match before title-independent matching is possible.

## Last ready presentation state

Once a native window has a verified icon, temporary metadata/decode/matching gaps
retain that image until replacement artwork is accepted, without a navigation
timer. This applies across paths, subdomains and domains. Retention uses a weak
Window reference and never transfers to an unknown window. Explicit resetIcons
clears all retained images; clearWindowIds clears private/non-web browser windows.
Disabling the local preference clears retained images. Closed windows are pruned
on refresh. Hidden/minimized and other ineligible windows do not display icons.
The last icon can remain when the new site has none or the extension is suspended;
this is presentation continuity, not a claim that the icon identifies the new site.
No persistent icon history is added. A never-matched window uses the app fallback.
