import AppKit
import Testing
@testable import ClipboardHero

@MainActor
@Test func storeCapturesDedupesSkipsConcealedTrimsAndPersists() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }

    let store = ClipboardStore(directory: dir, pasteboard: pasteboard)
    store.limit = 3

    func copy(_ text: String, concealed: Bool = false) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        if concealed { pasteboard.setData(Data(), forType: .init("org.nspasteboard.ConcealedType")) }
        store.poll()
    }
    func texts(_ store: ClipboardStore) -> [String?] { store.items.map(\.text) }

    copy("a")
    copy("b")
    copy("a")
    #expect(texts(store) == ["a", "b"])  // copying again moves to the top, no duplicate

    copy("password", concealed: true)
    copy("   ")
    #expect(texts(store) == ["a", "b"])  // concealed and blank items are skipped

    let rep = try #require(NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    pasteboard.clearContents()
    pasteboard.setData(rep.tiffRepresentation, forType: .tiff)
    store.poll()
    let image = try #require(store.items.first)
    let imageURL = store.imageURL(for: image)
    #expect(image.kind == .image)
    #expect(NSImage(contentsOf: imageURL) != nil)  // TIFF stored as PNG

    copy("c")
    copy("d")
    copy("e")
    #expect(texts(store) == ["e", "d", "c"])  // trimmed to the limit
    #expect(!FileManager.default.fileExists(atPath: imageURL.path))  // trimmed image file deleted

    #expect(texts(ClipboardStore(directory: dir, pasteboard: pasteboard)) == ["e", "d", "c"])  // reloaded from disk
}
