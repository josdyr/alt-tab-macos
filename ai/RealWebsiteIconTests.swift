import Foundation
@main struct RealWebsiteIconTests {
    static func main() {
        let pages = (ProcessInfo.processInfo.environment["ALTTAB_NATIVE_ICON_TEST_PAGES"] ?? "").split(separator: "|")
        precondition(!pages.isEmpty, "Supply the reviewed public test pages")
        precondition(!FixtureIconResolver.allowedPage(URL(string: "https://www.nrk.no/private?token=test")!))
        for raw in pages {
            let url = URL(string: String(raw))!
            let done = DispatchSemaphore(value: 0)
            let start = ProcessInfo.processInfo.systemUptime
            FixtureIconResolver.resolveArtwork(url) { artwork in
                precondition(artwork != nil, "No artwork returned for reviewed homepage: \(url.host!)")
                precondition(artwork?.image.width == 64 && artwork?.image.height == 64, "Expected normalized tile")
                print("\(url.host!): bitmap=\(artwork?.image.width ?? 0)x\(artwork?.image.height ?? 0) bytes=\(artwork?.data.count ?? 0) milliseconds=\(Int((ProcessInfo.processInfo.systemUptime - start) * 1000))")
                done.signal()
            }
            precondition(done.wait(timeout: .now() + 30) == .success)
        }
    }
}
