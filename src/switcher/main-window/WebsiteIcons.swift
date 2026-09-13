import Cocoa

/// Shows the displayed website's icon on browser windows. Works with any browser that exposes the standard accessibility
/// URL attributes; there is no browser-specific code. State and layer updates stay on the main thread.
final class WebsiteIcons {
    private struct Cached {
        weak var window: Window?
        let url: URL?
        let image: CGImage?
        let expires: Date
        let confirmed: Date
    }
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "website-icons"
        queue.maxConcurrentOperationCount = 4
        queue.qualityOfService = .utility
        return queue
    }()
    private static var cache: [ObjectIdentifier: Cached] = [:]
    private static var pending = Set<ObjectIdentifier>()
    private static var generation = 0
    static var enabled: Bool { Preferences.showWebsiteIcons }

    static func reset() {
        generation += 1
        cache.removeAll()
        pending.removeAll()
        WebsiteIconResolver.reset()
        for view in TilesView.recycledViews {
            if let window = view.window_ { view.updateDisplayedAppIcon(window.icon) }
        }
    }

    /// Returns the last known icon immediately and refreshes it in the background; the tile updates when it arrives.
    static func icon(for window: Window, retryBudget: Int = 2) -> CGImage? {
        // In-process AX calls re-enter AppKit, which must not happen off the main thread.
        guard enabled, window.application.pid != ProcessInfo.processInfo.processIdentifier,
              let element = window.axUiElement else { return nil }
        let key = ObjectIdentifier(window)
        let old = cache[key]?.window === window ? cache[key] : nil
        guard !pending.contains(key), pending.count < 32 else { return old?.image }
        if old?.url == nil, let expires = old?.expires, expires > Date() { return old?.image }
        pending.insert(key)
        let epoch = generation
        queue.addOperation { lookUp(window, element, key, old, retryBudget, epoch) }
        return old?.image
    }

    private static func lookUp(_ window: Window, _ element: AXUIElement, _ key: ObjectIdentifier, _ old: Cached?, _ retryBudget: Int, _ epoch: Int) {
        let document = documentURL(element)
        guard let url = document.flatMap(WebsiteIconResolver.homepage(for:)) else {
            DispatchQueue.main.async { withoutHomepage(window, key, document, old, retryBudget, epoch) }
            return
        }
        if old?.url == url, let old, old.expires > Date() {
            DispatchQueue.main.async {
                guard epoch == generation else { return }
                pending.remove(key)
                cache[key] = Cached(window: window, url: url, image: old.image, expires: old.expires, confirmed: Date())
            }
            return
        }
        WebsiteIconResolver.resolve(url) { image in
            queue.addOperation {
                let current = documentURL(element).flatMap(WebsiteIconResolver.homepage(for:))
                DispatchQueue.main.async {
                    guard epoch == generation, enabled else { return }
                    guard current == url else {
                        pending.remove(key)
                        retry(window, retryBudget, epoch)
                        return
                    }
                    finish(window, key, url, image ?? WebsiteIconRenderer.placeholder)
                }
            }
        }
    }

    /// Browsers briefly expose no URL while navigating: keep a recent icon and retry. A web page with no public homepage
    /// gets the globe; other windows (settings, new tab pages) keep the browser's icon.
    private static func withoutHomepage(_ window: Window, _ key: ObjectIdentifier, _ document: URL?, _ old: Cached?, _ retryBudget: Int, _ epoch: Int) {
        guard epoch == generation, enabled else { return }
        if document == nil, let old, old.image != nil, Date().timeIntervalSince(old.confirmed) < 8 {
            pending.remove(key)
            retry(window, retryBudget, epoch)
            return
        }
        finish(window, key, nil, ["http", "https"].contains(document?.scheme ?? "") ? WebsiteIconRenderer.placeholder : nil)
    }

    private static func retry(_ window: Window, _ budget: Int, _ epoch: Int) {
        guard budget > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard epoch == generation, SwitcherSession.isActive, Windows.list.contains(where: { $0 === window }) else { return }
            _ = icon(for: window, retryBudget: budget - 1)
        }
    }

    /// Safari exposes `AXDocument` on some windows; WebKit, Chromium and Firefox all expose `AXURL` on the tab's
    /// `AXWebArea`. The search stops at the first web area and never enters page content: at most 128 elements, depth 8,
    /// 1 second, 100ms per call. Chromium enables basic web accessibility for its process once a client reaches its web
    /// contents; on a page mutating 50 DOM nodes every 100ms this measured about 3 to 5% more Chrome CPU and no memory change.
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
                continue
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
        if cache.count >= 128, let oldest = cache.min(by: { $0.value.confirmed < $1.value.confirmed }) { cache.removeValue(forKey: oldest.key) }
        let lifetime: TimeInterval = url == nil ? 1 : (image === WebsiteIconRenderer.placeholder ? 5 : 30)
        cache[key] = Cached(window: window, url: url, image: image, expires: Date().addingTimeInterval(lifetime), confirmed: Date())
        guard SwitcherSession.isActive else { return }
        for view in TilesView.recycledViews where view.window_ === window {
            view.updateDisplayedAppIcon(image ?? window.icon)
        }
    }
}
