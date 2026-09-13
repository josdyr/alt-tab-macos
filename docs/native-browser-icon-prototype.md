# Extension-free browser icon laboratory

This branch demonstrates a shared in-process AltTab provider, not a release candidate. Ordinary launches continue using the existing provider. No browser extension, browser database, Apple Events, remote debugging, or extra helper permission is required by this experiment.

## Verified on this Mac, 2026-09-13

Safari 27 and Chrome 152 were opened on controlled pages with the same title and different 32px PNG icons. Safari's AltTab Site Icons checkbox was verified disabled. The prototype also bypasses AltTab's extension receiver when enabled, so an old companion snapshot cannot supply its results.

- The actual AltTab switcher visibly displayed Safari's blue square and Chrome's red square in their respective rows.
- Chrome navigation from red to blue, without a title change, produced a fresh 32px image and applied it to the same window's tile, verified in the native runtime log.
- The missing-icon fixture returned no artwork and applied the ordinary app fallback. Neutral missing-site placeholders and navigation continuity are not finished here.
- Standalone tests passed origin restrictions, relative icon discovery, invalid-image rejection, distinct decoded images and missing artwork. One local sample took 13ms, 3ms and 2ms respectively. These are not latency percentiles, CPU measurements or battery results.
- Debug build and deep/strict signing verification passed. Local SDK compatibility required deployment target 12 and disabling pre-existing warnings-as-errors, supplied as build overrides. This does not validate the project's normal older-macOS build matrix. The first launch lacked a build version; supplying CURRENT_PROJECT_VERSION fixed that harness failure.

## How it works

`NativeBrowserIconPrototype` first reads the window's AXDocument. If unavailable, it searches a bounded accessibility subtree for a web area's AXURL, without traversing the page content. Chrome used the first capability; Safari required the second. There are no browser-name or website-name branches.

Discovery runs on a serial utility queue, with per-element messaging timeouts and a bounded traversal. A cached bitmap returns immediately. The resolver independently downloads the fixture HTML, finds icon links, tries a root favicon fallback and decodes the result. It uses an ephemeral URLSession with no cookies, credentials or disk cache. Only HTTP on 127.0.0.1:18769 is allowed, including redirects and icon resources. External XML entities are disabled. URL ownership is checked again before asynchronous publication, and window identity, not title matching, selects the recipient tile.

## Reproduce

Serve the controlled fixtures from the companion research checkout:

```sh
python3 -m http.server 18769 --bind 127.0.0.1 --directory ~/dotfiles/macos/alt-tab-site-icons/prototypes/fixtures
```

Open `/native-blue.html` in Safari and `/native-red.html` in Chrome at that origin. Leave unrelated tabs alone. Disable the AltTab Site Icons Safari extension for independence testing. Build through the normal Xcode project, setting the development signing identity, team and CURRENT_PROJECT_VERSION as needed. The exact local verification command was:

```sh
xcodebuild -project alt-tab-macos.xcodeproj -scheme Debug -configuration Debug \
  -derivedDataPath /Users/josdyr/Developer/alt-tab-border/DerivedData \
  CURRENT_PROJECT_VERSION=11.6.1 MACOSX_DEPLOYMENT_TARGET=12.0 \
  CODE_SIGN_IDENTITY='Apple Development' DEVELOPMENT_TEAM=79YY3FK495 \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=NO GCC_TREAT_WARNINGS_AS_ERRORS=NO
swiftc src/switcher/main-window/FixtureIconResolver.swift ai/FixtureIconResolverTests.swift -o /tmp/alttab-native-resolver-tests
/tmp/alttab-native-resolver-tests
```

Quit the other AltTab instance before launching the built app through LaunchServices with `open -n --env ALTTAB_NATIVE_ICON_PROTOTYPE=1 -a <built-app>`. Do not launch the bare executable, which can change TCC responsibility. Existing AltTab permission was sufficient here. `--args --logs=debug --benchmark showUi 10` automatically displays the switcher ten times and exits; only this opt-in experiment extends each display to five seconds. Debug logs record fixture basenames, process IDs and decoded widths, not general browsing URLs. Restore the installed app after testing and stop the fixture server.

## Before broadening the experiment

- Establish private-window exclusion and explicit network consent. Knowing a URL does not establish permission to replay it or to fetch an authenticated page independently.
- Stop buffering at a streaming byte limit. The current 1MiB check is after URLSession buffers data, sufficient only for these trusted small fixtures. Add a total request budget and cancellation when windows close or navigate.
- Improve source selection and format coverage: base URLs, media/type/sizes, SVG, data URLs, manifests, high-quality touch icons, redirects and cross-origin CDN icons. XML tidy parsing is not a browser DOM or script engine.
- Complete loading/absent/invalid state handling, neutral placeholders, stale-result recovery, observer coverage, cache expiry and same-URL artwork refresh. The current cache deliberately does not refetch a settled unchanged URL. A changed URL at completion discards that result but needs a later update to retry.
- Measure UI responsiveness, CPU, wakeups, memory and duplicate decodes across many windows. The current image validation and publication decode twice; do not claim production efficiency from a three-request sample.
- Test background/minimized windows, tab changes, rapid navigation, no-title-change events, observer failures, other macOS releases, Firefox and other Chromium browsers. Their compatibility is not established by Chrome succeeding.

The conclusion is positive but bounded: shared extension-free icons are demonstrably possible. Exact reproduction of every browser-selected favicon, notification badge or script-updated artwork is not established. Keep this branch isolated until those requirements and privacy behavior are resolved.

## Cleanup

After verification, the automatic test build exited, the installed `/Applications/AltTab.app` was relaunched and its process path verified. Task-created fixture windows were closed and the loopback server stopped. Safari's extension toggle was already disabled at the start and was left unchanged. No installed app bundle was replaced.
