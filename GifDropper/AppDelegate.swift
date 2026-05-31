import AppKit
import SwiftUI
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store = Store()
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyEventHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        setupHotKey()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.stack", accessibilityDescription: "GIF Dropper")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PickerView().environment(store)
        )
    }

    private func setupHotKey() {
        // Register ⌥G as global hotkey (keyCode 5 = G, optionKey modifier)
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = fourCC("GifD")
        hotKeyID.id = 1
        RegisterEventHotKey(5, UInt32(optionKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        // Bridge C callback → NotificationCenter → MainActor
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, _) -> OSStatus in
                NotificationCenter.default.post(name: .gifDropperHotKey, object: nil)
                return OSStatus(noErr)
            },
            1, &eventType, nil, &hotKeyEventHandler
        )

        NotificationCenter.default.addObserver(
            forName: .gifDropperHotKey,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showPopover()
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
    }
}

private func fourCC(_ s: String) -> FourCharCode {
    s.prefix(4).utf8.reduce(0) { $0 << 8 | FourCharCode($1) }
}

extension Notification.Name {
    static let gifDropperHotKey = Notification.Name("gifDropperHotKey")
}
