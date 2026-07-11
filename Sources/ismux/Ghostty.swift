import AppKit

struct GhosttyWindow {
    let id: String
    let name: String
}

/// Talks to Ghostty via its AppleScript dictionary (Ghostty >= 1.3).
/// Window ids look like "tab-group-777a42120" and identify a whole tab
/// group, so a workspace's tabs travel with it. Ids are stable for the
/// window's lifetime but not across Ghostty restarts.
enum Ghostty {
    static let bundleID = "com.mitchellh.ghostty"

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    static func listWindows() -> [GhosttyWindow] {
        guard isRunning else { return [] }
        // `tab`/`linefeed` must be bound outside the tell block: Ghostty's
        // dictionary defines a `tab` class that shadows the character constant.
        let out = run("""
        set d to tab
        set lf to linefeed
        set out to ""
        tell application "Ghostty"
            repeat with w in windows
                set out to out & (id of w as text) & d & (name of w) & lf
            end repeat
        end tell
        return out
        """) ?? ""
        return out.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard let first = parts.first, !first.isEmpty else { return nil }
            return GhosttyWindow(id: String(first), name: parts.count > 1 ? String(parts[1]) : "")
        }
    }

    static func frontWindowID() -> String? {
        guard isRunning else { return nil }
        let id = run("tell application \"Ghostty\" to get id of front window as text")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (id?.isEmpty ?? true) ? nil : id
    }

    static func activate(windowID: String) {
        _ = run("""
        tell application "Ghostty"
            activate
            activate window (first window whose id is "\(escaped(windowID))")
        end tell
        """)
    }

    /// Opens a new window and returns its id.
    static func newWindow() -> String? {
        let id = run("""
        tell application "Ghostty"
            activate
            new window
            delay 0.4
            return id of front window as text
        end tell
        """)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (id?.isEmpty ?? true) ? nil : id
    }

    private static func escaped(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func run(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            NSLog("ismux: applescript error: %@", error)
            return nil
        }
        return result.stringValue
    }
}
