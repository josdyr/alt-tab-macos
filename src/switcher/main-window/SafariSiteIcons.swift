import Cocoa
import ImageIO

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
    private static var loading = false
    private static var lastLoad = Date.distantPast
    private static var snapshot: Snapshot?
    private static var images: [Int: CGImage] = [:]

    static func refresh() {
        guard UserDefaults.standard.bool(forKey: "localSafariSiteIcons"), !loading,
              Date().timeIntervalSince(lastLoad) > 1 else { return }
        loading = true
        lastLoad = Date()
        queue.async {
            let loaded = load()
            DispatchQueue.main.async {
                loading = false
                let changed = snapshot?.capturedAt != loaded.0?.capturedAt
                snapshot = loaded.0
                images = loaded.1
                if changed {
                    App.refreshOpenUiAfterExternalEvent(Windows.list.filter { $0.application.bundleIdentifier == "com.apple.Safari" })
                }
            }
        }
    }

    static func icon(for window: Window) -> CGImage? {
        guard UserDefaults.standard.bool(forKey: "localSafariSiteIcons"),
              Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex) == .titles,
              let snapshot, isFresh(snapshot.capturedAt), eligible(window) else { return nil }
        let records = snapshot.records.filter { matches($0, window) }
        guard let record = records.first,
              records.allSatisfy({ candidate in
                  snapshot.records.filter { $0.windowId == candidate.windowId }.count == 1
                      && images[candidate.windowId] != nil
              }),
              Windows.list.filter({ eligible($0) && matches(record, $0) }).count == records.count else { return nil }
        // Identical title/bounds cannot identify a window. An identical image across every
        // candidate is nevertheless safe to display; this does not establish window identity.
        if records.count > 1 {
            guard let png = record.png, records.allSatisfy({ $0.png == png }) else { return nil }
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
