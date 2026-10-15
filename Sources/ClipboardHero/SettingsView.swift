import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let store: ClipboardStore
    let hotKey: HotKey

    @State private var limit: Int
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginMessage: String?
    @State private var confirmClear = false

    init(store: ClipboardStore, hotKey: HotKey) {
        self.store = store
        self.hotKey = hotKey
        _limit = State(initialValue: store.limit)
    }

    var body: some View {
        Form {
            LabeledContent("Open search") {
                ShortcutRecorder(hotKey: hotKey)
            }

            Picker("Keep last", selection: $limit) {
                ForEach([100, 250, 500, 1000], id: \.self) { Text("\($0) items") }
            }
            .onChange(of: limit) {
                store.limit = limit
                UserDefaults.standard.set(limit, forKey: "historyLimit")
            }

            Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) }))
            if let loginMessage {
                Text(loginMessage).font(.caption).foregroundStyle(.secondary)
            }

            LabeledContent("History") {
                Button("Clear History…", role: .destructive) { confirmClear = true }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize()
        .confirmationDialog("Clear clipboard history?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { store.clear() }
        } message: {
            Text("All saved texts and images will be deleted.")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginMessage = nil
        } catch {
            loginMessage = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            loginMessage = "Allow Clipboard Hero in System Settings › General › Login Items."
        }
    }
}

/// Click, then press the new key combination. Esc cancels.
struct ShortcutRecorder: View {
    let hotKey: HotKey

    @State private var shortcut = Shortcut.saved
    @State private var monitor: Any?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button(monitor == nil ? shortcut.description : "Type shortcut…") {
                monitor == nil ? start() : stop()
            }
            .frame(minWidth: 120)
            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        message = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isEscape = event.keyCode == kVK_Escape
            let new = Shortcut(event: event)
            MainActor.assumeIsolated {
                if isEscape {
                    stop()
                } else if let new {
                    stop(with: new)
                } else {
                    message = "Use ⌘, ⌥ or ⌃ with a key."
                }
            }
            return nil  // keys typed while recording go nowhere else
        }
    }

    private func stop(with new: Shortcut? = nil) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard let new, new != shortcut else { return }

        if hotKey.register(new) {
            shortcut = new
            Shortcut.saved = new
        } else {
            message = "\(new.description) is already used by another app."
            hotKey.register(shortcut)
        }
    }
}
