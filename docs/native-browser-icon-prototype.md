# Native icon stress and real-site follow-up, 2026-09-13

The updated prototype was visually verified in the **actual AltTab switcher** with VG in Safari, NRK in Safari and Chrome, Tek in Safari, GitHub in Safari and YouTube in Chrome. The user also confirmed seeing the controlled red/blue demonstration. This was not the standalone Safari Icon Preview.

## Changes and measurements

- Share in-flight page requests and decoded artwork. Different pages referencing one asset share its download and decoded image. Cache at most 32 page entries and 32 asset entries, with 30-second positive and 5-second negative lifetimes. Window-level unchanged-URL freshness remains a separate unresolved limit.
- Stream with a 1MiB retained-buffer cap, reject oversized declared bodies, cap redirects at three, and limit connections per host to four. Page requests stop after the HTML head, avoiding downloading a large body merely to find icon links. No scripts are executed and no browser cookies or credentials are imported.
- Preserve the last ready image when discarding an obsolete completion and immediately retry the current URL with a bounded retry budget. A live Chrome fixture automatically navigated while its slow icon was pending: the log recorded the obsolete result discarded, then the blue destination image applied to the tile. This is one controlled race, not exhaustive lifecycle coverage.

The final standalone stress run completed in 0.93 seconds, with 0.04 seconds user CPU and 0.01 seconds system CPU. Maximum resident size was 20,168,704 bytes, and reported peak footprint was 7,701,176 bytes. These belong to the isolated resolver executable, **not total AltTab or browser memory**.

| Workload | Observed result |
| --- | --- |
| 128 callers for a page delayed 600ms | One page fetch, one icon fetch; p95 626.9ms including intentional delay |
| 1,000 subsequent callers | Shared decoded bitmap; p95 0.080ms; no new requests |
| 16 distinct pages sharing artwork | 16 page fetches, one asset fetch; p95 8.69ms; identical CGImage reused |
| 128 missing-icon callers | One page fetch and one failed favicon request; p95 2.83ms |
| Oversized declared/chunked bodies, external redirect, redirect loop | Rejected; loop stops after three redirects |
| Allowed local redirect | Resolved correctly |

Before asset coalescing, the same 16-page experiment fetched its common artwork repeatedly. The post-change server counters and image-identity assertions verify that this duplicate work was removed. These single local runs are useful regression checks, not statistically robust production benchmarks. The integrated build also ran repeated automatic switcher openings, but there is no matched baseline for its CPU, memory, wakeups or input latency.

## Current user-testable state

The real-site prototype was left running without the automatic benchmark after verification. Its containing app is still a separate development build; `/Applications/AltTab.app` was not overwritten. The old standalone Safari Icon Preview and the local fixture server were stopped. The task-created GitHub Safari window and YouTube Chrome window were left open for user testing; unrelated windows were preserved. Only the reviewed homepages are eligible, not arbitrary article pages or browsing URLs. Restarting the installed app restores its normal provider.

## Real-site test policy and results

`ai/native-icon-sites.json` lists five explicit public homepage URLs and their observed published icon URLs. The code has no website-specific renderer or browser-name branch. The JSON is a reviewed experiment allowlist, not production site overrides. Article paths, query-bearing URLs and unrelated sites are not enabled. The list prevents scanning/refetching the user's whole browsing session while private-window handling remains unresolved.

| Homepage | Native decoded artwork | One warm-network sample |
| --- | --- | --- |
| NRK | 32×32, 663 bytes | 202ms |
| VG | 180×180, 1,575 bytes | 86ms |
| Tek | 32×32, 1,340 bytes | 68ms |
| GitHub | 32×32, 958 bytes | 181ms |
| YouTube | 32×32, 5,430 bytes | 259ms |

YouTube initially failed because URLSession received a redirect to its mobile homepage, outside the original allowlist. A direct diagnostic confirmed the redirect and published mobile favicon. Adding those two reviewed URLs allowed the generic resolver to succeed. This illustrates a fidelity difference from the user's desktop browser; no YouTube-specific retrieval code was added. Public-source requests are anonymous and may produce different HTML from a signed-in browser.

For a fresh run, build as documented below and use:

```sh
python3 ai/native-icon-server.py
swiftc src/switcher/main-window/FixtureIconResolver.swift ai/FixtureIconStressTests.swift -o /tmp/alttab-native-stress
/usr/bin/time -l /tmp/alttab-native-stress
swiftc src/switcher/main-window/FixtureIconResolver.swift ai/RealWebsiteIconTests.swift -o /tmp/alttab-real-icons
python3 ai/run-native-icon-demo.py /tmp/alttab-real-icons
# Quit the other AltTab instance before launching this separately built bundle.
python3 ai/run-native-icon-demo.py /path/to/AltTab.app --logs=debug
```

The public-site demo does not need the local server. Open a listed homepage in Safari or Chrome and invoke AltTab normally. The helper only supplies environment variables to that process; it writes no persistent preferences or login item. The normal installed app does not acquire these options. Quit the prototype and reopen `/Applications/AltTab.app` to return to the installed build. The prototype's ordinary missing/unsupported-site fallback still uses the app icon; full globe and navigation state integration is unfinished.

Sources: Apple's [streaming response/data delegate](https://developer.apple.com/documentation/foundation/urlsessiondatadelegate) and [connection limit](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/httpmaximumconnectionsperhost). Connection limits do not by themselves cap the number of queued logical resolutions. Before release, add global admission/cancellation budgets, robust private-mode policy, complete event coverage, supported-format and appearance tests, and matched full-process performance measurements.

The earlier laboratory record follows for provenance. Its post-buffer limit and double-decoding limitations were addressed above; its other unverified release gates still apply.

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
