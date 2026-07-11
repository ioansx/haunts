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
}

/// Reads ~/.local/state/haunts/agents/<session>.json files written by the
/// Claude Code hooks.
enum AgentStates {
    static let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/state/haunts/agents")

    /// All live agents. Files older than a day are ignored (leftovers from
    /// crashed sessions).
    static func all() -> [AgentState] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }
        let cutoff = Date().addingTimeInterval(-86_400)
        return files.compactMap { file in
            guard file.pathExtension == "json" else { return nil }
            if let mtime = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               mtime < cutoff { return nil }
            guard let data = try? Data(contentsOf: file),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let cwd = obj["cwd"], !cwd.isEmpty,
                  let status = obj["status"].flatMap(AgentStatus.init(rawValue:))
            else { return nil }
            return AgentState(file: file, cwd: cwd, status: status)
        }
    }

    /// herdr semantics: a "done" agent whose workspace has been focused was
    /// seen — drop it back to idle.
    static func markIdle(_ state: AgentState) {
        let obj = ["cwd": state.cwd, "status": AgentStatus.idle.rawValue]
        if let data = try? JSONSerialization.data(withJSONObject: obj) {
            try? data.write(to: state.file, options: .atomic)
        }
    }
}
