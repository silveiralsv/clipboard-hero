import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class SearchModel: ObservableObject {
    @Published var query = "" { didSet { if query != oldValue { selected = 0 } } }  // the field also writes back unchanged values
    @Published var selected = 0
    @Published private(set) var items: [ClipItem] = []
    @Published private(set) var session = 0  // bumped on every open to rebuild the view and refocus the field

    // ponytail: linear scan per keystroke; fine for ~500 items, index if history grows to thousands.
    var results: [ClipItem] {
        query.isEmpty ? items : items.filter { $0.text?.localizedCaseInsensitiveContains(query) == true }
    }

    var selectedItem: ClipItem? {
        let results = results
        return results.indices.contains(selected) ? results[selected] : nil
    }

    func reset(items: [ClipItem]) {
        self.items = items
        query = ""
        session += 1
    }

    func move(_ delta: Int) {
        selected = min(max(selected + delta, 0), max(results.count - 1, 0))
    }
}

/// Spotlight-style floating panel. It never activates the app, so focus goes back to the previous app when it closes.
@MainActor
final class SearchPanel: NSPanel {
    private let store: ClipboardStore
    private let model = SearchModel()
    private var keyMonitor: Any?

    init(store: ClipboardStore) {
        self.store = store
        super.init(contentRect: NSRect(x: 0, y: 0, width: 760, height: 460),
                   styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(button)?.isHidden = true
        }

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        let content = NSHostingView(rootView: SearchView(model: model, store: store) { [weak self] in self?.pick($0) })
        content.frame = background.bounds
        content.autoresizingMask = [.width, .height]
        background.addSubview(content)
        contentView = background
    }

    override var canBecomeKey: Bool { true }

    func toggle() {
        keyMonitor == nil ? show() : dismiss()
    }

    func show() {
        model.reset(items: store.items)

        // Upper third of the screen the mouse is on, like Spotlight.
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main {
            let area = screen.visibleFrame
            setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: area.minY + area.height * 0.62 - frame.height / 2))
        }

        makeKeyAndOrderFront(nil)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let handled = MainActor.assumeIsolated { self?.handle(keyCode) ?? false }
            return handled ? nil : event
        }
    }

    func dismiss() {
        guard let keyMonitor else { return }  // also stops re-entry from resignKey() below
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
        orderOut(nil)
    }

    // Clicking anywhere outside closes the panel.
    override func resignKey() {
        super.resignKey()
        dismiss()
    }

    /// Returns true when the key was used, so it doesn't reach the search field.
    private func handle(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_DownArrow: model.move(1)
        case kVK_UpArrow: model.move(-1)
        case kVK_Return, kVK_ANSI_KeypadEnter: if let item = model.selectedItem { pick(item) }
        case kVK_Escape: dismiss()
        default: return false
        }
        return true
    }

    private func pick(_ item: ClipItem) {
        store.copy(item)
        dismiss()
    }
}

struct SearchView: View {
    @ObservedObject var model: SearchModel
    let store: ClipboardStore
    let pick: (ClipItem) -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        let results = model.results
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard history", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
            }
            .font(.title2)
            .padding(.horizontal, 18)
            .frame(height: 56)

            Divider()

            if results.isEmpty {
                Text(model.items.isEmpty ? "Nothing copied yet" : "No results")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    list(results)
                        .frame(width: 300)
                    Divider()
                    preview(model.selectedItem)
                }
            }
        }
        .ignoresSafeArea()
        .id(model.session)
        .onAppear { searchFocused = true }
    }

    private func list(_ results: [ClipItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                        row(item, isSelected: index == model.selected)
                            .onTapGesture { pick(item) }
                    }
                }
                .padding(8)
            }
            .onChange(of: model.selected) { _, selected in
                if results.indices.contains(selected) { proxy.scrollTo(results[selected].id) }
            }
        }
    }

    private func row(_ item: ClipItem, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Group {
                if item.kind == .image, let thumbnail = store.thumbnail(for: item, size: 28) {
                    Image(nsImage: thumbnail).resizable().scaledToFit()
                } else {
                    Image(systemName: "doc.text").foregroundStyle(isSelected ? .white : .secondary)
                }
            }
            .frame(width: 28, height: 28)
            Text(item.title)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    private func preview(_ item: ClipItem?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let item {
                if item.kind == .image, let image = store.thumbnail(for: item, size: 420) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: image.size.width, maxHeight: image.size.height)  // never upscale small images
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        // Long texts are cut so a huge paste does not stall the layout.
                        Text((item.text ?? "").prefix(10_000))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text(item.date, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
