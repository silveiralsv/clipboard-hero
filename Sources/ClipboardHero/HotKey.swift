import AppKit
import Carbon.HIToolbox

/// A key combination, stored with the label shown to the user (e.g. "⌥Space").
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt  // NSEvent.ModifierFlags raw value
    var key: String

    static let `default` = Shortcut(keyCode: UInt32(kVK_Space), modifiers: NSEvent.ModifierFlags.option.rawValue, key: "Space")

    static var saved: Shortcut {
        get {
            UserDefaults.standard.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .default
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "shortcut") }
    }

    private static let keyNames: [UInt16: String] = [
        UInt16(kVK_Space): "Space", UInt16(kVK_Return): "↩", UInt16(kVK_Tab): "⇥", UInt16(kVK_Delete): "⌫",
        UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→", UInt16(kVK_DownArrow): "↓", UInt16(kVK_UpArrow): "↑",
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3", UInt16(kVK_F4): "F4",
        UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6", UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8",
        UInt16(kVK_F9): "F9", UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
    ]

    /// Builds a shortcut from a key press; nil unless it uses ⌘, ⌥ or ⌃, so plain typing can't become a global hotkey.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let key = Self.keyNames[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
        guard !key.isEmpty, !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: flags.rawValue, key: key)
    }

    init(keyCode: UInt32, modifiers: UInt, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    var description: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        return (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "")
            + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "") + key
    }

    var carbonModifiers: UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        var result = 0
        if flags.contains(.command) { result |= cmdKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.shift) { result |= shiftKey }
        return UInt32(result)
    }
}

/// Global hotkey through Carbon's RegisterEventHotKey: works from any app and needs no Accessibility permission.
@MainActor
final class HotKey {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?

    init(action: @escaping () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // Lives as long as the app, so the unretained pointer stays valid.
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            MainActor.assumeIsolated { Unmanaged<HotKey>.fromOpaque(userData!).takeUnretainedValue().action() }
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// Replaces the current hotkey. Returns false when the combination is taken by another app.
    @discardableResult
    func register(_ shortcut: Shortcut?) -> Bool {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        guard let shortcut else { return true }
        let id = EventHotKeyID(signature: OSType(0x4348_524F), id: 1)  // "CHRO"
        return RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr
    }
}
