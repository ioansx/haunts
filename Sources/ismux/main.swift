import AppKit
import Carbon.HIToolbox

// ismux — workspace switcher for Ghostty.
// ⌃⌥1-9 switches to a workspace (creates a window on an empty slot),
// ⌃⌥⇧1-9 assigns Ghostty's front window to a workspace.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Workspaces()
    let hotkeys = Hotkeys()
    var rail: RailController?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ note: Notification) {
        model.start()
        rail = RailController(model: model)
        setupHotkeys()
        setupStatusItem()
    }

    private func setupHotkeys() {
        let switchMods = UInt32(controlKey | optionKey)
        let assignMods = UInt32(controlKey | optionKey | shiftKey)
        for i in 0..<Workspaces.slots {
            hotkeys.register(id: UInt32(i + 1), keyCode: digitKeyCodes[i], modifiers: switchMods) { [model] in
                model.switchTo(i)
            }
            hotkeys.register(id: UInt32(100 + i), keyCode: digitKeyCodes[i], modifiers: assignMods) { [model] in
                model.assignFrontWindow(to: i)
            }
        }
        // ⌃⌥0 — new workspace (key code 29 = ANSI 0)
        hotkeys.register(id: 200, keyCode: 29, modifiers: switchMods) { [model] in
            model.addWorkspace()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.split.2x2", accessibilityDescription: "ismux")
        let menu = NSMenu()
        let refresh = NSMenuItem(title: "Refresh", action: #selector(doRefresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ismux", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func doRefresh() { model.refresh() }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run() // returns only on quit; keeps `delegate` alive
}
