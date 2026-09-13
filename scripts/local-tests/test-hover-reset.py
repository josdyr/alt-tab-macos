"""Exercise the real hover reset and refresh reanchoring with UI stand-ins."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
def method(path, start, end):
    text = (root / path).read_text()
    return text[text.index(start):text.index(end, text.index(start))]
reset = method('src/switcher/main-window/TileOverView.swift',
               '    func resetHoveredWindow()', '    // MARK: - Window controls')
refresh = method('src/switcher/state/Windows.swift',
                 '    private static func reanchorHover(', '    private static func applySelectionDecision(')
selection = method('src/switcher/state/Windows.swift',
                   '    private static func applySelectionDecision(', '    static func cycleSelectedWindowIndex(')
fixture = """
import Cocoa
enum Activity { case focus, hover }
enum Preferences { static var mouseHoverEnabled = false }
enum WindowThumbnails {
 static func previewSelectedIfNeeded() {}
 static func fetchPreviewFrames() {}
}
final class Scroller { func scrollToVisible(_ frame: CGRect) {} }
final class ScrollView { let contentView = Scroller() }
struct Tile { let frame = CGRect.zero }

final class SwitcherSession {
 var removalFallback: SelectionRemovalFallback?
 static var current: SwitcherSession?
 var selectedIndex = 0
 var selectedTarget: String? = "a"
 var userPickedSelection = true
 var hoveredIndex: Int?
 var hoveredTarget: String?
}
enum TilesView {
 static let thumbnailOverView = Overlay()
 static let recycledViews = [Tile(), Tile()]
 static let scrollView = ScrollView()
 static var repaints = [Int]()
 static func highlight(_ index: Int) {
  precondition(SwitcherSession.current?.hoveredTarget == nil ||
               SwitcherSession.current?.hoveredIndex != nil)
  repaints.append(index)
 }
}
final class Overlay {
 var previousTarget: Int?
 var hidden = false
 func hideWindowControls() { hidden = true }
RESET
}
enum Windows {
 struct Window { let id: String }
 static var list = [Window(id:"a"), Window(id:"b")]
REFRESH
SELECTION
 static var lastWindowActivityType = Activity.focus
 static func shouldDisplay(_ window: Window) -> Bool { true }
 static func voiceOverWindow(_ index: Int) {}
 static func refresh() {
  let session = SwitcherSession.current!
  applySelectionDecision(.selectAt(session.selectedIndex), session: session)
  reanchorHover(session)
 }

}
@main struct Regression {
 static func main() {
  let overlay = Overlay()
  for index in [nil, Optional(1)] {
   let session = SwitcherSession(); SwitcherSession.current = session
   session.hoveredIndex = index; session.hoveredTarget = "b"
   overlay.previousTarget = 1
   overlay.resetHoveredWindow()
   precondition(session.hoveredIndex == nil && session.hoveredTarget == nil)
   precondition(overlay.previousTarget == nil && overlay.hidden)
   for _ in 0..<100 {
    Windows.list.reverse()
    Windows.refresh()
    precondition(session.hoveredIndex == nil && session.hoveredTarget == nil)
   }
   // A new genuine hover still follows its window when rows reorder.
   session.hoveredIndex = 1; session.hoveredTarget = "b"
   Windows.list = [.init(id:"b"), .init(id:"a")]
   Windows.refresh()
   precondition(session.hoveredIndex == 0)
   overlay.resetHoveredWindow()
   overlay.resetHoveredWindow()
   Windows.refresh()
   precondition(session.hoveredIndex == nil && session.hoveredTarget == nil)
  }
  // A stationary pointer must keep hover through the full selection-refresh path.
  for mouseSelects in [false, true] {
   Preferences.mouseHoverEnabled = mouseSelects
   let session = SwitcherSession(); SwitcherSession.current = session
   Windows.list = [.init(id:"a"), .init(id:"b")]
   Windows.updateSelectedAndHoveredWindowIndex(1, true)
   session.removalFallback = .init(target: "b", candidates: ["a"])
   for _ in 0..<100 {
    Windows.refresh()
    precondition(session.removalFallback != nil, "Refresh discarded action intent")
    precondition(session.hoveredIndex == 1 && session.hoveredTarget == "b",
                 "Title refresh cleared stationary hover")
   }
   Windows.updateSelectedAndHoveredWindowIndex(0)
   precondition(session.removalFallback == nil, "Navigation retained old action intent")
   Windows.refresh()
   precondition(session.hoveredIndex == nil && session.hoveredTarget == nil)
  }
  SwitcherSession.current = nil
  overlay.resetHoveredWindow()
  print("Hover passed: 400 refreshes, stationary pointer, both hover modes, keyboard dismissal, stale identity, reordering, repeated reset, no session")
 }
}
""".replace('RESET', reset).replace('REFRESH', refresh).replace('SELECTION', selection)
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    (tmp/'test.swift').write_text(fixture)
    subprocess.run(['swiftc', str(root/'src/switcher/state/SelectionResolver.swift'),
                    str(tmp/'test.swift'), '-o', str(tmp/'test')], check=True)
    subprocess.run([str(tmp/'test')], check=True)
