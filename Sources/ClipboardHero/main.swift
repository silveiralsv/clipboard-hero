import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let store = ClipboardStore()
    private lazy var panel = SearchPanel(store: store)
    private lazy var hotKey = HotKey { [weak self] in self?.panel.toggle() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()
        hotKey.register(.saved)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Hero")
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self
    }

    // Rebuilt every time the menu opens, so it always shows the latest items.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let recent = store.items.prefix(5)
        if recent.isEmpty {
            menu.addItem(withTitle: "No items yet", action: nil, keyEquivalent: "")
        }
        for item in recent {
            let menuItem = menu.addItem(withTitle: item.title, action: #selector(copyItem(_:)), keyEquivalent: "")
            menuItem.representedObject = item
            if item.kind == .image {
                menuItem.image = store.thumbnail(for: item, size: 40)
            }
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Search History…", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(.separator())
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        menu.addItem(withTitle: "Version \(version)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Quit Clipboard Hero", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @objc private func showPanel() {
        panel.show()
    }

    @objc private func copyItem(_ sender: NSMenuItem) {
        if let item = sender.representedObject as? ClipItem { store.copy(item) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
