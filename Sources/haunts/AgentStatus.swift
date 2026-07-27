import Foundation

/// Agent lifecycle state reported by the Claude Code hooks
/// (hooks/haunts-agent-status). Same states as herdr: idle, working,
/// blocked, done — ordered by display priority for aggregation.
enum AgentStatus: String, Comparable {
    case idle
    case done
    case working
    case blocked

    private var rank: Int {
        switch self {
        case .idle: 0
        case .done: 1
        case .working: 2
        case .blocked: 3
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

struct AgentState {
    let file: URL
    let cwd: String
    let status: AgentStatus
    let pid: pid_t?
}

/// Reads ~/.local/state/haunts/agents/<session>.json files written by the
/// Claude Code hooks.
enum AgentStates {
    static let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/state/haunts/agents")

    /// All live agents. A session killed without a SessionEnd event leaves
    /// its file behind, so a state is dropped once its Claude process is
    /// gone — or, for files written without a pid, after a day.
    static func all() -> [AgentState] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }
        let cutoff = Date().addingTimeInterval(-86_400)
        return files.compactMap { file in
            guard file.pathExtension == "json",
                  let data = try? Data(contentsOf: file),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let cwd = obj["cwd"], !cwd.isEmpty,
                  let status = obj["status"].flatMap(AgentStatus.init(rawValue:))
            else { return nil }
            let pid = obj["pid"].flatMap(pid_t.init)
            if let pid {
                guard isRunning(pid) else { return nil }
            } else if let mtime = try? file.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate, mtime < cutoff {
                return nil
            }
            return AgentState(file: file, cwd: cwd, status: status, pid: pid)
        }
    }

    /// EPERM means the process exists but belongs to someone else.
    private static func isRunning(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    /// herdr semantics: a "done" agent whose workspace has been focused was
    /// seen — drop it back to idle.
    static func markIdle(_ state: AgentState) {
        var obj = ["cwd": state.cwd, "status": AgentStatus.idle.rawValue]
        if let pid = state.pid { obj["pid"] = String(pid) }
        if let data = try? JSONSerialization.data(withJSONObject: obj) {
            try? data.write(to: state.file, options: .atomic)
        }
    }
}
