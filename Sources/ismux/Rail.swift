import SwiftUI
import Combine

struct RailView: View {
    @ObservedObject var model: Workspaces

    var body: some View {
        VStack(spacing: 4) {
            ForEach(model.usedSlots, id: \.self) { i in
                row(i)
            }
            addRow
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.10, green: 0.10, blue: 0.11)))
    }

    private func row(_ i: Int) -> some View {
        let isActive = model.active == i
        return HStack(spacing: 6) {
            Text("\(i + 1)")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: isActive ? 0.92 : 0.62))
            if isActive {
                Circle()
                    .strokeBorder(Color.yellow.opacity(0.85), lineWidth: 1.5)
                    .frame(width: 9, height: 9)
            } else {
                Circle()
                    .fill(Color(white: 0.55))
                    .frame(width: 4, height: 4)
                    .frame(width: 9, height: 9)
            }
        }
        .frame(width: 44, height: 24)
        .contentShape(Rectangle())
        .onTapGesture { model.switchTo(i) }
        .help(model.names[i])
    }

    private var addRow: some View {
        Image(systemName: "plus")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(white: 0.4))
            .frame(width: 44, height: 24)
            .contentShape(Rectangle())
            .onTapGesture { model.addWorkspace() }
            .help("New workspace (⌃⌥0)")
    }
}

/// Owns the floating rail panel: borderless, non-activating, draggable,
/// pinned to the left screen edge, resizing (top-anchored) as workspaces
/// come and go.
@MainActor
final class RailController {
    let panel: NSPanel
    private let host: NSHostingView<RailView>
    private var sub: AnyCancellable?
    private var activationObserver: NSObjectProtocol?

    init(model: Workspaces) {
        host = NSHostingView(rootView: RailView(model: model))
        let size = host.fittingSize
        host.setFrameSize(size)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.minX + 6, y: f.midY - size.height / 2))
        }
        // Only show the rail while Ghostty is the frontmost app.
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.setVisible(app?.bundleIdentifier == Ghostty.bundleID)
        }
        setVisible(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Ghostty.bundleID)

        // objectWillChange fires pre-mutation; the main-queue hop makes
        // resize() run after SwiftUI has applied the update.
        sub = model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.resize() }
    }

    private func setVisible(_ visible: Bool) {
        if visible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func resize() {
        let size = host.fittingSize
        guard size != panel.frame.size else { return }
        let top = panel.frame.maxY
        panel.setContentSize(size)
        panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: top - size.height))
    }
}
