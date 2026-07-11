import AppKit

struct GhosttyWindow {
    let id: String
    let name: String
    let cwds: [String]
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
                set l to (id of w as text) & d & (name of w)
                repeat with t in terminals of w
                    try
                        set l to l & d & (working directory of t as text)
                    end try
                end repeat
                set out to out & l & lf
            end repeat
        end tell
        return out
        """) ?? ""
        return out.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard let id = parts.first, !id.isEmpty else { return nil }
            return GhosttyWindow(
                id: id,
                name: parts.count > 1 ? parts[1] : "",
                cwds: Array(parts.dropFirst(2))
            )
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

    /// Screen frame (Cocoa coordinates) of Ghostty's frontmost window, via
    /// CGWindowList — no permissions needed for bounds, and cheap enough to
    /// poll. Returns nil if Ghostty has no window on the active Space.
    static func frontWindowFrame() -> NSRect? {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first,
            let list = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
            ) as? [[String: Any]]
        else { return nil }
        for info in list {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pid == app.processIdentifier,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let b = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let w = b["Width"], let h = b["Height"],
                  w > 100, h > 100
            else { continue }
            // CGWindow coords are top-left origin; Cocoa are bottom-left of
            // the primary screen.
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            return NSRect(x: x, y: primaryHeight - y - h, width: w, height: h)
        }
        return nil
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
            NSLog("haunts: applescript error: %@", error)
            return nil
        }
        return result.stringValue
    }
}
