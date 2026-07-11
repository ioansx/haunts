import AppKit
import Combine

/// Nine numbered workspaces, each mapped to one Ghostty window (tab group).
@MainActor
final class Workspaces: ObservableObject {
    static let slots = 9

    @Published private(set) var windowIDs: [String?] = Array(repeating: nil, count: slots)
    @Published private(set) var names: [String] = Array(repeating: "", count: slots)
    @Published private(set) var active: Int?

    private let defaults = UserDefaults.standard
    private let key = "workspaceWindowIDs"
    private var timer: Timer?

    func start() {
        if let saved = defaults.stringArray(forKey: key), saved.count == Self.slots {
            windowIDs = saved.map { $0.isEmpty ? nil : $0 }
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Slots that have a window, in display order.
    var usedSlots: [Int] {
        windowIDs.indices.filter { windowIDs[$0] != nil }
    }

    /// Open a new window in the first free slot and switch to it.
    func addWorkspace() {
        guard let free = windowIDs.firstIndex(of: nil) else { return }
        switchTo(free)
    }

    /// Raise the workspace's window; on an empty slot, create a window for it.
    func switchTo(_ slot: Int) {
        if let id = windowIDs[slot] {
            Ghostty.activate(windowID: id)
        } else if let id = Ghostty.newWindow() {
            windowIDs[slot] = id
            save()
        }
        refresh()
    }

    /// Bind Ghostty's current front window to a slot (removing it from any other).
    func assignFrontWindow(to slot: Int) {
        guard let id = Ghostty.frontWindowID() else { return }
        for i in windowIDs.indices where windowIDs[i] == id { windowIDs[i] = nil }
        windowIDs[slot] = id
        save()
        refresh()
    }

    /// Re-sync with Ghostty: drop windows that no longer exist, adopt new
    /// ones into free slots, update names and which workspace is active.
    func refresh() {
        let windows = Ghostty.listWindows()
        let live = Dictionary(
            windows.map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        var changed = false
        for i in windowIDs.indices where windowIDs[i] != nil {
            if live[windowIDs[i]!] == nil {
                windowIDs[i] = nil
                changed = true
            }
        }
        let bound = Set(windowIDs.compactMap { $0 })
        for w in windows where !bound.contains(w.id) {
            guard let free = windowIDs.firstIndex(of: nil) else { break }
            windowIDs[free] = w.id
            changed = true
        }
        for i in windowIDs.indices {
            names[i] = windowIDs[i].flatMap { live[$0] } ?? ""
        }
        if changed { save() }
        let front = Ghostty.frontWindowID()
        active = front.flatMap { f in windowIDs.firstIndex(of: f) }
    }

    private func save() {
        defaults.set(windowIDs.map { $0 ?? "" }, forKey: key)
    }
}
