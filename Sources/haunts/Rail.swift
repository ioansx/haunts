import SwiftUI
import Combine

/// Horizontal, chromeless workspace strip that rides the empty right half
/// of the focused Ghostty window's title bar.
struct RailView: View {
    @ObservedObject var model: Workspaces
    /// Live drag: which used-slot position is being dragged, and how far.
    @State private var drag: (position: Int, translation: CGFloat)?

    /// Tile width (22) + HStack spacing (3).
    private static let pitch: CGFloat = 25

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(model.usedSlots.enumerated()), id: \.element) { position, i in
                RailRow(
                    label: Workspaces.keys[i].label,
                    isActive: model.active == i,
                    status: model.statuses[i],
                    name: model.names[i]
                ) { model.switchTo(i) }
                    .offset(x: offsetX(forPosition: position))
                    .zIndex(drag?.position == position ? 1 : 0)
                    .animation(
                        drag?.position == position ? nil : .easeOut(duration: 0.15),
                        value: offsetX(forPosition: position)
                    )
                    .gesture(dragGesture(position: position))
            }
            if !model.usedSlots.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 12)
                    .padding(.horizontal, 2)
            }
            AddRow { model.addWorkspace() }
        }
        .padding(.horizontal, 4)
        .frame(height: 24)
    }

    private func dragGesture(position: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                drag = (position, value.translation.width)
            }
            .onEnded { value in
                let target = dropPosition(from: position, translation: value.translation.width)
                drag = nil
                model.moveWorkspace(fromPosition: position, toPosition: target)
            }
    }

    /// The used-slot position the dragged tile would land on.
    private func dropPosition(from: Int, translation: CGFloat) -> Int {
        let raw = from + Int((translation / Self.pitch).rounded())
        return max(0, min(model.usedSlots.count - 1, raw))
    }

    /// The dragged tile follows the cursor; tiles it has crossed step aside.
    private func offsetX(forPosition position: Int) -> CGFloat {
        guard let drag else { return 0 }
        if position == drag.position { return drag.translation }
        let target = dropPosition(from: drag.position, translation: drag.translation)
        if drag.position < position, position <= target { return -Self.pitch }
        if target <= position, position < drag.position { return Self.pitch }
        return 0
    }
}

private struct RailRow: View {
    let label: String
    let isActive: Bool
    let status: AgentStatus?
    let name: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(isActive ? 1.0 : hovered ? 0.85 : 0.5))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(isActive ? 0.18 : hovered ? 0.10 : 0))
            )
            .overlay(alignment: .topTrailing) {
                if let status {
                    Badge(status: status)
                        .offset(x: 1.5, y: -1.5)
                }
            }
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: hovered)
            // No animation on the switch itself: the highlight should already
            // be on the new number by the time the window comes up.
            .animation(nil, value: isActive)
            .onTapGesture(perform: action)
            .onHover { inside in
                hovered = inside
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .help(name.isEmpty ? "Workspace \(label)" : name)
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
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(status == .idle ? 0 : 0.7), radius: 2.5)
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
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(.white.opacity(hovered ? 0.9 : 0.4))
            .frame(width: 20, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(hovered ? 0.10 : 0))
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: hovered)
            .onTapGesture(perform: action)
            .onHover { inside in
                hovered = inside
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .help("New workspace (⌘⌥0)")
    }
}

/// Owns the rail panel and keeps it glued to the title bar of Ghostty's
/// focused window (right-aligned), hiding whenever Ghostty isn't frontmost.
@MainActor
final class RailController {
    let panel: NSPanel
    private let host: NSHostingView<RailView>
    private var sub: AnyCancellable?
    private var activationObserver: NSObjectProtocol?
    private var positionTimer: Timer?
    private var ghosttyIsFront = false

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
        panel.hasShadow = false
        // Keep colors dark regardless of system appearance.
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        // Hover must work even though this panel never becomes key.
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let isGhostty = app?.bundleIdentifier == Ghostty.bundleID
            MainActor.assumeIsolated { // observer queue is .main
                self?.ghosttyIsFront = isGhostty
                self?.reposition()
            }
        }
        ghosttyIsFront = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Ghostty.bundleID

        // Track the window as it moves/resizes. CGWindowList is microseconds
        // per call; 0.25s keeps the rail feeling attached without AX perms.
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reposition() }
        }

        sub = model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.reposition() }
            }
        reposition()
    }

    private func reposition() {
        guard ghosttyIsFront, let windowFrame = Ghostty.frontWindowFrame() else {
            panel.orderOut(nil)
            return
        }
        let size = host.fittingSize
        if size != panel.frame.size {
            panel.setContentSize(size)
        }
        // Right-aligned in the title bar row (top ~28pt of the window).
        let origin = NSPoint(
            x: windowFrame.maxX - size.width - 10,
            y: windowFrame.maxY - size.height - 3
        )
        if origin != panel.frame.origin {
            panel.setFrameOrigin(origin)
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }
}
