import AppKit
import Combine

/// Nine numbered workspaces, each mapped to one Ghostty window (tab group).
@MainActor
final class Workspaces: ObservableObject {
    static let slots = 9

    @Published private(set) var windowIDs: [String?] = Array(repeating: nil, count: slots)
    @Published private(set) var names: [String] = Array(repeating: "", count: slots)
    @Published private(set) var statuses: [AgentStatus?] = Array(repeating: nil, count: slots)
    @Published private(set) var active: Int?

    private let defaults = UserDefaults.standard
    private let key = "workspaceWindowIDs"
    private var timer: Timer?
    private var agentDirWatcher: DispatchSourceFileSystemObject?

    func start() {
        if let saved = defaults.stringArray(forKey: key), saved.count == Self.slots {
            windowIDs = saved.map { $0.isEmpty ? nil : $0 }
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        watchAgentDir()
    }

    /// Refresh immediately when a hook writes/renames a status file, so
    /// badges update without waiting for the poll tick.
    private func watchAgentDir() {
        try? FileManager.default.createDirectory(at: AgentStates.dir, withIntermediateDirectories: true)
        let fd = open(AgentStates.dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: .main
        )
        source.setEventHandler { [weak self] in self?.refresh() }
        source.setCancelHandler { close(fd) }
        source.resume()
        agentDirWatcher = source
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

    /// Reorder: move the window at used-slot position `from` to position `to`,
    /// shifting the windows between. Numbers stay put; windows change numbers.
    func moveWorkspace(fromPosition from: Int, toPosition to: Int) {
        let slots = usedSlots
        guard from != to, slots.indices.contains(from), slots.indices.contains(to) else { return }
        var ids = slots.map { windowIDs[$0] }
        ids.insert(ids.remove(at: from), at: to)
        for (i, slot) in slots.enumerated() { windowIDs[slot] = ids[i] }
        save()
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
    /// ones into free slots, update names, agent statuses, and which
    /// workspace is active.
    func refresh() {
        let windows = Ghostty.listWindows()
        let live = Dictionary(
            windows.map { ($0.id, $0) },
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
            names[i] = windowIDs[i].flatMap { live[$0]?.name } ?? ""
        }
        if changed { save() }
        let front = Ghostty.frontWindowID()
        active = front.flatMap { f in windowIDs.firstIndex(of: f) }
        updateStatuses(live: live)
    }

    /// Map each agent (by its cwd) to the workspace whose window has the
    /// longest matching working-directory prefix; a workspace's worst agent
    /// status wins. Longest-prefix means an agent in ~/dev/proj lands on
    /// the ~/dev/proj window even if another window sits in ~. The focused
    /// workspace's "done" agents count as seen and drop back to idle.
    private func updateStatuses(live: [String: GhosttyWindow]) {
        var slotAgents: [[AgentState]] = Array(repeating: [], count: Self.slots)
        for agent in AgentStates.all() {
            var best: (slot: Int, length: Int)?
            for i in windowIDs.indices {
                guard let id = windowIDs[i], let win = live[id] else { continue }
                for cwd in win.cwds where agent.cwd == cwd || agent.cwd.hasPrefix(cwd + "/") {
                    if best == nil || cwd.count > best!.length {
                        best = (i, cwd.count)
                    }
                }
            }
            if let best { slotAgents[best.slot].append(agent) }
        }
        if let active {
            for agent in slotAgents[active] where agent.status == .done {
                AgentStates.markIdle(agent)
            }
            slotAgents[active] = slotAgents[active].map {
                $0.status == .done ? AgentState(file: $0.file, cwd: $0.cwd, status: .idle) : $0
            }
        }
        statuses = slotAgents.map { $0.map(\.status).max() }
    }

    private func save() {
        defaults.set(windowIDs.map { $0 ?? "" }, forKey: key)
    }
}
