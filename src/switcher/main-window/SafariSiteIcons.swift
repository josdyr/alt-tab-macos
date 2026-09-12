import Cocoa
import ImageIO
import os.log

/// Local experiment: only fresh, uniquely matched Safari snapshots can replace a Titles icon.
final class SafariSiteIcons {
    struct Snapshot: Decodable {
        let capturedAt: Double
        let records: [Record]
    }
    struct Record: Decodable {
        let windowId: Int
        let title: String
        let left: Double
        let top: Double
        let width: Double
        let height: Double
        let png: String?
        var bounds: [Double] { [left, top, width, height] }
    }
    private static let queue = DispatchQueue(label: "local.safari-site-icons", qos: .utility)
    private static let diagnosticLog = OSLog(subsystem: "com.josdyr.alttab-site-icons", category: "provider")
    private static var lastDiagnostic: [String: Date] = [:]
    private static func diagnostic(_ reason: String) {
        guard Date().timeIntervalSince(lastDiagnostic[reason] ?? .distantPast) >= 10 else { return }
        lastDiagnostic[reason] = Date()
        os_log("Icon state: %{public}@", log: diagnosticLog, type: .info, reason)
    }
    private static var loading = false
    private static var lastLoad = Date.distantPast
    private static var snapshot: Snapshot?
    private static var images: [Int: CGImage] = [:]

    private static var watcher: DispatchSourceFileSystemObject?
    private static var pendingRefresh = false
    private static var expiry: DispatchWorkItem?

    private static func startWatching() {
        guard watcher == nil,
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "79YY3FK495.com.josdyr.alttab-site-icons") else { return }
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        // Observe the directory because atomic snapshot writes replace the file inode.
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { refresh(force: true) }
        source.setCancelHandler { close(descriptor) }
        watcher = source
        source.resume()
    }

    private static func updateVisibleIcons() {
        guard SwitcherSession.isActive else { return }
        for view in TilesView.recycledViews {
            guard let window = view.window_, window.application.bundleIdentifier == "com.apple.Safari" else { continue }
            view.updateDisplayedAppIcon(icon(for: window) ?? window.icon)
        }
    }

    static func refresh(force: Bool = false) {
        guard UserDefaults.standard.bool(forKey: "localSafariSiteIcons") else { return }
        startWatching()
        if loading { pendingRefresh = pendingRefresh || force; return }
        guard force || Date().timeIntervalSince(lastLoad) > 1 else { return }
        loading = true
        lastLoad = Date()
        queue.async {
            let loaded = load()
            DispatchQueue.main.async {
                loading = false
                let changed = snapshot?.capturedAt != loaded.0?.capturedAt
                if loaded.0 == nil { diagnostic("snapshot-unavailable-or-expired") }
                else if loaded.1.isEmpty { diagnostic("snapshot-without-decodable-icons") }
                snapshot = loaded.0
                images = loaded.1
                if changed {
                    expiry?.cancel()
                    updateVisibleIcons()
                    if let snapshot {
                        let work = DispatchWorkItem { updateVisibleIcons() }
                        expiry = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, snapshot.capturedAt + 60.01 - Date().timeIntervalSince1970), execute: work)
                    }
                }
                if pendingRefresh { pendingRefresh = false; refresh(force: true) }
            }
        }
    }

    static func icon(for window: Window) -> CGImage? {
        guard UserDefaults.standard.bool(forKey: "localSafariSiteIcons"),
              Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex) == .titles,
              eligible(window) else { return nil }
        guard let snapshot else { diagnostic("no-snapshot"); return nil }
        guard isFresh(snapshot.capturedAt) else { diagnostic("snapshot-expired"); return nil }
        let records = snapshot.records.filter { matches($0, window) }
        guard let record = records.first else { diagnostic("title-or-bounds-unmatched"); return nil }
        guard records.allSatisfy({ candidate in
                  snapshot.records.filter { $0.windowId == candidate.windowId }.count == 1
                      && images[candidate.windowId] != nil
              }),
              Windows.list.filter({ eligible($0) && matches(record, $0) }).count == records.count else { diagnostic("ambiguous-or-missing-image"); return nil }
        // Identical title/bounds cannot identify a window. An identical image across every
        // candidate is nevertheless safe to display; this does not establish window identity.
        if records.count > 1 {
            guard let png = record.png, records.allSatisfy({ $0.png == png }) else { diagnostic("ambiguous-different-images"); return nil }
        }
        return images[record.windowId]
    }

    private static func eligible(_ window: Window) -> Bool {
        window.application.bundleIdentifier == "com.apple.Safari" && window.cgWindowId != nil
            && !window.isWindowlessApp && !window.isTabbed && !window.isMinimized
            && !window.isFullscreen && !window.application.isHidden
    }

    private static func matches(_ record: Record, _ window: Window) -> Bool {
        guard !record.title.isEmpty, record.title == window.title,
              let position = window.position, let size = window.size else { return false }
        let geometry = [Double(position.x), Double(position.y), Double(size.width), Double(size.height)]
        return record.width > 0 && record.height > 0
            && zip(record.bounds, geometry).allSatisfy { $0.isFinite && $1.isFinite && abs($0 - $1) <= 2 }
    }

    private static func isFresh(_ timestamp: Double) -> Bool {
        let age = Date().timeIntervalSince1970 - timestamp
        return age.isFinite && age >= 0 && age <= 60
    }

    private static func load() -> (Snapshot?, [Int: CGImage]) {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "79YY3FK495.com.josdyr.alttab-site-icons") else { return (nil, [:]) }
        let url = directory.appendingPathComponent("snapshot.json")
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 6 * 1024 * 1024,
              let data = try? Data(contentsOf: url), data.count <= 6 * 1024 * 1024,
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              isFresh(snapshot.capturedAt), snapshot.records.count <= 16 else { return (nil, [:]) }
        var images: [Int: CGImage] = [:]
        for record in snapshot.records {
            guard let encoded = record.png, encoded.count <= 350000,
                  let data = Data(base64Encoded: encoded), data.count <= 262144,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
                  let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight as String] as? Int,
                  (32...64).contains(width), (32...64).contains(height),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { continue }
            images[record.windowId] = image
        }
        return (snapshot, images)
    }
}
