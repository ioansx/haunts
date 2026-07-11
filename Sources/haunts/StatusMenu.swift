import AppKit
import Combine
import ServiceManagement

/// Menu bar presence: the button shows the active workspace number (with an
/// amber dot when any agent is blocked — visible from any app), and the menu
/// is a full workspace switcher.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let model: Workspaces
    private let item: NSStatusItem
    private var sub: AnyCancellable?

    init(model: Workspaces) {
        self.model = model
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        sub = model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateButton() }
        updateButton()
    }

    private func updateButton() {
        guard let button = item.button else { return }
        let needsAttention = model.statuses.compactMap { $0 }.contains(.blocked)
        if let active = model.active {
            button.image = nil
            let title = NSMutableAttributedString(
                string: "\(active + 1)",
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)]
            )
            if needsAttention {
                title.append(NSAttributedString(string: " ●", attributes: [
                    .font: NSFont.systemFont(ofSize: 8),
                    .foregroundColor: NSColor.systemOrange,
                    .baselineOffset: 2,
                ]))
            }
            button.attributedTitle = title
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.image = NSImage(systemSymbolName: "square.split.2x2", accessibilityDescription: "Haunts")
        }
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        model.refresh()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        for i in model.usedSlots {
            let mi = NSMenuItem(title: "", action: #selector(switchTo(_:)), keyEquivalent: "\(i + 1)")
            mi.keyEquivalentModifierMask = [.control, .option]
            mi.target = self
            mi.tag = i
            mi.state = model.active == i ? .on : .off
            mi.attributedTitle = rowTitle(slot: i)
            menu.addItem(mi)
        }

        let add = NSMenuItem(title: "New Workspace", action: #selector(addWorkspace), keyEquivalent: "0")
        add.keyEquivalentModifierMask = [.control, .option]
        add.target = self
        menu.addItem(add)

        menu.addItem(.separator())

        let assign = NSMenuItem(title: "Move Front Window To", action: nil, keyEquivalent: "")
        let assignMenu = NSMenu()
        for i in 0..<Workspaces.slots {
            let mi = NSMenuItem(title: "Workspace \(i + 1)", action: #selector(assignTo(_:)), keyEquivalent: "\(i + 1)")
            mi.keyEquivalentModifierMask = [.control, .option, .shift]
            mi.target = self
            mi.tag = i
            assignMenu.addItem(mi)
        }
        assign.submenu = assignMenu
        menu.addItem(assign)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(NSMenuItem(title: "Quit Haunts", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func rowTitle(slot: Int) -> NSAttributedString {
        let status = model.statuses[slot]
        let dotColor: NSColor = switch status {
        case .blocked: .systemOrange
        case .working: .systemBlue
        case .done: .systemGreen
        case .idle: .tertiaryLabelColor
        case nil: NSColor.labelColor.withAlphaComponent(0.12)
        }
        var name = model.names[slot]
        if name.count > 34 { name = name.prefix(33) + "…" }
        let title = NSMutableAttributedString(string: "● ", attributes: [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: dotColor,
            .baselineOffset: 1.5,
        ])
        title.append(NSAttributedString(
            string: "\(slot + 1)   \(name)",
            attributes: [.font: NSFont.menuFont(ofSize: 0)]
        ))
        return title
    }

    // MARK: - Actions

    @objc private func switchTo(_ sender: NSMenuItem) { model.switchTo(sender.tag) }
    @objc private func assignTo(_ sender: NSMenuItem) { model.assignFrontWindow(to: sender.tag) }
    @objc private func addWorkspace() { model.addWorkspace() }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("haunts: launch-at-login toggle failed: %@", error.localizedDescription)
        }
    }
}
