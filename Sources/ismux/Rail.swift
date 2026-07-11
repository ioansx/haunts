import SwiftUI
import Combine

private let railShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

struct RailView: View {
    @ObservedObject var model: Workspaces

    var body: some View {
        VStack(spacing: 2) {
            ForEach(model.usedSlots, id: \.self) { i in
                RailRow(
                    number: i + 1,
                    isActive: model.active == i,
                    status: model.statuses[i],
                    name: model.names[i]
                ) { model.switchTo(i) }
            }
            if !model.usedSlots.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 14, height: 1)
                    .padding(.vertical, 3)
            }
            AddRow { model.addWorkspace() }
        }
        .padding(6)
        .background(railShape.fill(.regularMaterial))
        .background(railShape.fill(Color.black.opacity(0.28)))
        .overlay(railShape.strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }
}

private struct RailRow: View {
    let number: Int
    let isActive: Bool
    let status: AgentStatus?
    let name: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Text("\(number)")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(isActive ? 1.0 : hovered ? 0.85 : 0.55))
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isActive ? 0.17 : hovered ? 0.10 : 0))
            )
            .overlay(alignment: .topTrailing) {
                if let status {
                    Badge(status: status)
                        .offset(x: 1.5, y: -1.5)
                }
            }
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: hovered)
            .animation(.easeOut(duration: 0.15), value: isActive)
            .onTapGesture(perform: action)
            .onHover { inside in
                hovered = inside
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .help(name.isEmpty ? "Workspace \(number)" : name)
    }
}

/// Status dot with an LED-style glow; pulses gently while working.
private struct Badge: View {
    let status: AgentStatus
    @State private var pulsing = false

    private var color: Color {
        switch status {
        case .blocked: Color(red: 1.0, green: 0.62, blue: 0.25)
        case .working: Color(red: 0.45, green: 0.68, blue: 1.0)
        case .done: Color(red: 0.5, green: 0.9, blue: 0.55)
        case .idle: Color(white: 0.55)
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(status == .idle ? 0 : 0.7), radius: 3)
            .opacity(status == .working && pulsing ? 0.4 : 1)
            .animation(
                status == .working
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}

private struct AddRow: View {
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.white.opacity(hovered ? 0.9 : 0.45))
            .frame(width: 28, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(hovered ? 0.10 : 0))
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: hovered)
            .onTapGesture(perform: action)
            .onHover { inside in
                hovered = inside
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .help("New workspace (⌃⌥0)")
    }
}

/// Owns the floating rail panel: borderless, non-activating, draggable,
/// floating near the top-right corner, resizing (top-right anchored) as
/// workspaces come and go. Visible only while Ghostty is frontmost.
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
        // Keep the material/colors dark regardless of system appearance.
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        // Hover must work even though this panel never becomes key.
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.maxX - size.width - 8, y: f.maxY - size.height - 8))
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
        let right = panel.frame.maxX
        panel.setContentSize(size)
        panel.setFrameOrigin(NSPoint(x: right - size.width, y: top - size.height))
    }
}
