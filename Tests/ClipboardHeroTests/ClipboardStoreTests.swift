import AppKit
import Carbon.HIToolbox
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

@MainActor
@Test func copyingAnItemBackMovesItToTheTopWithoutDuplicating() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    let store = ClipboardStore(directory: dir, pasteboard: pasteboard)

    let rep = try #require(NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    pasteboard.clearContents()
    pasteboard.setData(rep.tiffRepresentation, forType: .tiff)
    store.poll()
    pasteboard.clearContents()
    pasteboard.setString("  first line\n\n  second   line  ", forType: .string)
    store.poll()

    let image = store.items[1]
    store.copy(image)
    store.poll()
    #expect(store.items.count == 2 && store.items[0].id == image.id)

    let text = store.items[1]
    #expect(text.title == "first line second line")
    store.copy(text)
    store.poll()
    #expect(store.items.map(\.id) == [text.id, image.id])
}

@MainActor
@Test func searchFiltersCaseInsensitivelyAndKeepsSelectionInRange() {
    let item = { (text: String?) in ClipItem(id: UUID(), kind: text == nil ? .image : .text, text: text, hash: UUID().uuidString, date: .now) }
    let model = SearchModel()
    model.reset(items: [item("Hello World"), item(nil), item("hello again"), item("bye")])

    model.move(-1)
    #expect(model.selected == 0)
    model.move(10)
    #expect(model.selected == 3)

    model.query = "HELLO"
    #expect(model.results.map(\.text) == ["Hello World", "hello again"])  // images don't match text queries
    #expect(model.selected == 0)  // typing resets the selection
    model.move(5)
    #expect(model.selectedItem?.text == "hello again")

    model.query = "nothing"
    model.move(1)
    #expect(model.selectedItem == nil)
}

@Test func shortcutRequiresAModifierAndShowsMacSymbols() throws {
    func press(_ characters: String, _ keyCode: Int, _ flags: NSEvent.ModifierFlags) -> Shortcut? {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                         characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: UInt16(keyCode))
            .flatMap(Shortcut.init(event:))
    }

    #expect(Shortcut.default.description == "⌥Space")
    #expect(press("v", 9, [.command, .shift])?.description == "⇧⌘V")
    #expect(press(" ", 49, [.control, .option])?.description == "⌃⌥Space")
    #expect(press("v", 9, []) == nil)
    #expect(press("V", 9, [.shift]) == nil)

    let shortcut = try #require(press("k", 40, [.command, .option]))
    #expect(shortcut.carbonModifiers == UInt32(cmdKey | optionKey))
    #expect(try JSONDecoder().decode(Shortcut.self, from: JSONEncoder().encode(shortcut)) == shortcut)
}
