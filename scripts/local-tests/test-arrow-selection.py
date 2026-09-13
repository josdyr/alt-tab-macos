"""Compile the real vertical navigation methods and selection resolver with UI stand-ins."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / 'src/switcher/main-window/TilesView.swift').read_text()
start = source.index('    static func nextRow(')
end = source.index('    static func updateItemsAndLayout(', start)
methods = source[start:end]
fixture = r'''
import Cocoa
enum Direction { case up, down }
final class Session { var selectedIndex = 1; var userPickedSelection = false }
enum SwitcherSession { static var current: Session? = Session() }
final class TileView: Equatable {
 let frame: CGRect; let rowIndex: Int
 init(_ x: Int, _ row: Int) { frame = CGRect(x:x*100,y:row*40,width:100,height:40); rowIndex = row }
 static func == (a: TileView,b: TileView) -> Bool { a === b }
}
final class App { static let shared = App(); var userInterfaceLayoutDirection = NSUserInterfaceLayoutDirection.leftToRight }
enum Windows {
 static func selectedWindow() -> TileView? { TilesView.recycledViews[SwitcherSession.current!.selectedIndex] }
 static func updateSelectedAndHoveredWindowIndex(_ index: Int) { SwitcherSession.current!.selectedIndex = index }
}
enum TilesView {
 static var recycledViews = [TileView]()
 static var rows = [[TileView]]()
 static var contentView = NSView(frame:CGRect(x:0,y:0,width:200,height:200))
METHODS
}
@main struct Regression {
 static func main() {
  var checks = 0
  for columns in [1,2] {
   TilesView.rows = (0..<4).map { row in (0..<columns).map { TileView($0,row) } }
   TilesView.recycledViews = TilesView.rows.flatMap { $0 }
   let list = TilesView.recycledViews.indices.map { SelectionWindow(id:String($0),visible:true,lastFocusOrder:$0,isMinimized:false,isWindowlessApp:false) }
   for direction in [Direction.up,.down] {
    for initial in TilesView.recycledViews.indices {
     for wrap in [true,false] {
      let session=Session(); session.selectedIndex=initial; SwitcherSession.current=session
      let edge = direction == .up ? initial/columns == 0 : initial/columns == 3
      TilesView.navigateUpOrDown(direction,allowWrap:wrap)
      if edge && !wrap { precondition(!session.userPickedSelection); checks += 1; continue }
      precondition(session.userPickedSelection,"Arrow choice was not committed")
      let selected=session.selectedIndex
      for _ in 0..<30 {
       let input=SelectionInputs(list:list,selectedIndex:selected,selectedTarget:String(selected),useLastFocusedRule:false,visibleCountAtSummon:list.count,userPickedSelection:session.userPickedSelection,restoreDefaultOnSearchClear:false,bestMatchOnSearchChange:false)
       precondition(SelectionResolver.decide(input) == .selectAt(selected),"Refresh reset arrow selection")
       checks += 1
      }
     }
    }
   }
  }
  print("\(checks) arrow/refresh assertions passed")
 }
}
'''.replace('METHODS', methods)
with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    (tmp/'test.swift').write_text(fixture)
    subprocess.run(['swiftc', str(root/'src/switcher/state/SelectionResolver.swift'), str(tmp/'test.swift'), '-o', str(tmp/'test')], check=True)
    subprocess.run([str(tmp/'test')], check=True)
