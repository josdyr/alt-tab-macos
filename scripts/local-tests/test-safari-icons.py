#!/usr/bin/env python3
"""Compile the actual provider with small model stubs; no browser or app mutation."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
stubs = '''
import Cocoa
class Application { var bundleIdentifier = "com.apple.Safari"; var isHidden = false }
class Window {
 let application = Application()
 var cgWindowId: UInt32? = 10
 var isWindowlessApp = false
 var isTabbed = false
 var isMinimized = false
 var isFullscreen = false
 var title = "Example"
 var position: CGPoint? = CGPoint(x: 0, y: 0)
 var size: CGSize? = CGSize(width: 800, height: 600)
}
class Windows { static var list: [Window] = [] }
class App { static func refreshOpenUiAfterExternalEvent(_ windows: [Window]) {} }
enum Style { case titles, appIcons }
class Preferences { static var style = Style.titles; static func effectiveAppearanceStyle(_ i: Int) -> Style { style } }
class SwitcherSession { static var activeShortcutIndex = 0 }
'''
tests = '''
extension SafariSiteIcons {
 static func runChecks() {
  UserDefaults.standard.register(defaults: ["localSafariSiteIcons": true])
  let window = Window()
  Windows.list = [window]
  let image = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
  let record = Record(windowId: 1, title: "Example", left: 0, top: 0, width: 800, height: 600, png: nil)
  snapshot = Snapshot(capturedAt: Date().timeIntervalSince1970, records: [record])
  images = [1: image]
  precondition(icon(for: window) != nil, "unique match")
  Windows.list.append(Window())
  precondition(icon(for: window) == nil, "duplicate native windows")
  Windows.list = [window]
  snapshot = Snapshot(capturedAt: Date().timeIntervalSince1970, records: [record, record])
  precondition(icon(for: window) == nil, "duplicate browser records")
  snapshot = Snapshot(capturedAt: Date().timeIntervalSince1970 - 61, records: [record])
  precondition(icon(for: window) == nil, "stale")
  snapshot = Snapshot(capturedAt: Date().timeIntervalSince1970 + 60, records: [record])
  precondition(icon(for: window) == nil, "future")
  snapshot = Snapshot(capturedAt: Date().timeIntervalSince1970, records: [record])
  window.title = "Changed"; precondition(icon(for: window) == nil, "navigation"); window.title = "Example"
  window.position = CGPoint(x: 20,y: 0); precondition(icon(for: window) == nil, "moved"); window.position = .zero
  window.application.isHidden = true; precondition(icon(for: window) == nil, "hidden"); window.application.isHidden = false
  window.application.bundleIdentifier = "other"; precondition(icon(for: window) == nil, "different app"); window.application.bundleIdentifier = "com.apple.Safari"
  Preferences.style = .appIcons; precondition(icon(for: window) == nil, "other style"); Preferences.style = .titles
  images = [:]; precondition(icon(for: window) == nil, "missing image")
  print("11 production-provider checks passed")
 }
}
SafariSiteIcons.runChecks()
'''
with tempfile.TemporaryDirectory(prefix='alttab-icon-tests-') as directory:
    source = Path(directory)/'main.swift'
    source.write_text(stubs + (root/'src/switcher/main-window/SafariSiteIcons.swift').read_text() + tests)
    executable = Path(directory)/'checks'
    subprocess.run(['xcrun','swiftc',str(source),'-o',str(executable)],check=True)
    subprocess.run([str(executable)],check=True)
