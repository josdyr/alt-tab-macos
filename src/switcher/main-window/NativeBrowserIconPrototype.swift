import Cocoa
import ImageIO

/// Opt-in laboratory provider. Only the local fixture origin is eligible until privacy and network policy are validated.
final class NativeBrowserIconPrototype {
    private struct Cached {
        weak var window: Window?
        let url: URL
        let image: CGImage?
    }
    private static let queue = DispatchQueue(label: "local.native-browser-icon-prototype", qos: .utility)
    private static var cache: [ObjectIdentifier: Cached] = [:]
    private static var pending = Set<ObjectIdentifier>()
    static var enabled: Bool { ProcessInfo.processInfo.environment["ALTTAB_NATIVE_ICON_PROTOTYPE"] == "1" }
    static func icon(for window: Window) -> CGImage? {
        guard enabled, let element = window.axUiElement else { return nil }
        let key = ObjectIdentifier(window)
        if !pending.contains(key) {
            pending.insert(key)
            let old = cache[key]
            queue.async {
                let url = documentURL(element).flatMap { FixtureIconResolver.allowed($0) ? $0 : nil }
                guard let url else {
                    DispatchQueue.main.async { finish(window, key, nil, nil) }
                    return
                }
                if old?.url == url {
                    DispatchQueue.main.async { pending.remove(key) }
                    return
                }
                FixtureIconResolver.resolve(url) { data in
                    queue.async {
                        guard documentURL(element) == url else {
                            DispatchQueue.main.async { pending.remove(key); cache.removeValue(forKey: key) }
                            return
                        }
                        let image = data.flatMap { FixtureIconResolver.image($0) }
                        DispatchQueue.main.async { finish(window, key, url, image) }
                    }
                }
            }
        }
        return cache[key]?.window === window ? cache[key]?.image : nil
    }
    /// Some browsers expose the document on the window; others expose its URL on the web area.
    private static func documentURL(_ root: AXUIElement) -> URL? {
        func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
            AXUIElementSetMessagingTimeout(element, 0.1)
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(element, name as CFString, &value)
            return value
        }
        if let text = attribute(root, kAXDocumentAttribute) as? String, let url = URL(string: text) { return url }
        var remaining = [(root, 0)]
        let deadline = Date().addingTimeInterval(1)
        var visited = 0
        while let (element, depth) = remaining.popLast(), visited < 128, Date() < deadline {
            visited += 1
            if attribute(element, kAXRoleAttribute) as? String == "AXWebArea" {
                if let url = attribute(element, kAXURLAttribute) as? URL { return url }
                if let text = attribute(element, kAXURLAttribute) as? String { return URL(string: text) }
                continue // Never traverse page content.
            }
            if depth < 8, let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                remaining.append(contentsOf: children.prefix(128 - visited).reversed().map { ($0, depth + 1) })
            }
        }
        return nil
    }
    private static func finish(_ window: Window, _ key: ObjectIdentifier, _ url: URL?, _ image: CGImage?) {
        pending.remove(key)
        cache = cache.filter { $0.value.window != nil }
        guard Windows.list.contains(where: { $0 === window }) else { cache.removeValue(forKey: key); return }
        cache[key] = url.map { Cached(window: window, url: $0, image: image) }
        if let url { Logger.info { "native fixture resolved pid=\(window.application.pid) file=\(url.lastPathComponent) width=\(image?.width ?? 0)" } }
        guard SwitcherSession.isActive else { return }
        for view in TilesView.recycledViews where view.window_ === window {
            view.updateDisplayedAppIcon(image ?? window.icon)
            if let url { Logger.info { "native fixture applied to tile pid=\(window.application.pid) file=\(url.lastPathComponent) width=\(image?.width ?? 0)" } }
        }
    }
}
