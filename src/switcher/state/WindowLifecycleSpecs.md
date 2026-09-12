# Window lifecycle — Specs

WindowServer owns the physical surface; AX owns the app-side element; neither may silently stand in for the
other. The reducer records `unverified`, `alive`, `axElementEnded`, `replacementPending`, `surfaceEnded`, and
`confirmedClosed` so an element generation ending is separate from a user-facing window ending.

## AX element end

`AXUIElementDestroyed` moves the window to `axElementEnded` and requests reconciliation. A fresh element for
the same wid heals it to `alive`. Independent WindowServer absence, a scoped non-tab AX absence with a retained
surface, or a positive tab-count shrink may confirm closure. Unknown, other-Space, and incomplete answers
remain `replacementPending`. The join is time-bounded and late results cannot revive a completed verdict.

## WindowServer surface end

An 804 definitively retires that surface and removes its live `Window`, but keeps a two-second semantic
retirement record containing MRU time, creation order, thumbnail, group membership, and whether it represented
the app's focus. A new wid may inherit those facts only when it belongs to the same process and its AX element
is explicitly equal. A focus that happened after retirement prevents the replacement from stealing the front.

Process exit clears pending AX facts and surface retirements immediately.

## Observability ceiling

If a custom app retains both its AX element and WindowServer surface, posts no meaningful transition, and the
user action was not observed, AltTab cannot know that the user considers the window closed. No provider
priority or extra same-subsystem query can manufacture that fact.

## Tests

- **testWindowServerDestroyRetiresTheSurfaceBeforeRemovingIt**
- **testAxElementEndWaitsForCrossSourceReconciliation**
- **testAxReplacementHealsWhileConfirmedCloseRemoves**
- AX reconciliation policy cases live in `AxObserverHealthTests`.

## Device Hub focus

An existing Device Hub window requests activation of its running application and raises the selected AX
window on the accessibility command queue. LaunchServices reopen is a fallback when activation or AX raise
fails, followed by a fresh lookup/raise of that same window. A minimized target is restored first. No
LaunchServices or Accessibility round trip blocks switcher dismissal on the main thread. Preview cleanup
runs on main after the command finishes, with no fixed delay.

A later AltTab focus request cancels queued Device Hub work and suppresses its fallback and completion.
An IPC request already sent to macOS cannot be recalled. Public activation is advisory; API success does not
guarantee every third-party/Space transition, so actual front-window stacking remains a live verification gate.

Local probe on 2026-09-12: four activate-plus-raise trials moved the existing Device Hub window from second
to first among normal on-screen windows. Activation and raise returned within 25–42 ms together. The
comparison reopen returned in 86 ms. These are command timings, not release-to-first-frame measurements;
the user's roughly one-second preview handoff was not reproduced by the standalone probe.
