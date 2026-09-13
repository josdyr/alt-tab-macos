import Foundation
import ImageIO

/// Deliberately restricted experiment: no external hosts, cookies, credentials, scripts, browser databases, or extensions.
final class FixtureIconResolver: NSObject, URLSessionTaskDelegate {
    static func allowed(_ url: URL) -> Bool {
        url.scheme == "http" && url.host == "127.0.0.1" && url.port == 18769 && url.user == nil && url.password == nil
    }
    private static let delegate = FixtureIconResolver()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 4
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.map(Self.allowed) == true ? request : nil)
    }
    static func image(_ data: Data) -> CGImage? {
        guard data.count <= 1_048_576, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int, let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 512, height <= 512 else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    static func candidates(_ data: Data, page: URL) -> [URL] {
        guard data.count <= 1_048_576,
              let doc = try? XMLDocument(data: data, options: [.documentTidyHTML, .nodeLoadExternalEntitiesNever]),
              let nodes = try? doc.nodes(forXPath: "//link") else { return [] }
        let links = nodes.compactMap { node -> URL? in
            guard let element = node as? XMLElement,
                  let rel = element.attribute(forName: "rel")?.stringValue?.lowercased().split(whereSeparator: { $0.isWhitespace }),
                  rel.contains("icon"), let href = element.attribute(forName: "href")?.stringValue,
                  let url = URL(string: href, relativeTo: page)?.absoluteURL, allowed(url) else { return nil }
            return url
        }
        return Array(links.prefix(8)) + [URL(string: "/favicon.ico", relativeTo: page)!.absoluteURL]
    }
    private static func fetch(_ url: URL, _ completion: @escaping (Data?, URL) -> Void) {
        guard allowed(url) else { completion(nil, url); return }
        session.dataTask(with: url) { data, response, _ in
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  let finalURL = response.url, allowed(finalURL), let data, data.count <= 1_048_576 else {
                completion(nil, url); return
            }
            completion(data, finalURL)
        }.resume()
    }
    static func resolve(_ page: URL, completion: @escaping (Data?) -> Void) {
        fetch(page) { data, finalURL in
            guard let data else { completion(nil); return }
            next(candidates(data, page: finalURL), completion)
        }
    }
    private static func next(_ urls: [URL], _ completion: @escaping (Data?) -> Void) {
        guard let first = urls.first else { completion(nil); return }
        fetch(first) { data, _ in
            if let data, image(data) != nil { completion(data) }
            else { next(Array(urls.dropFirst()), completion) }
        }
    }
}
