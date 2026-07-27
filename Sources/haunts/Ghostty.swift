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

    /// Three bulk property fetches rather than one per window and one per
    /// terminal: the same data in ~25ms instead of ~210ms. This runs on every
    /// poll and every workspace switch, so it has to be cheap.
    ///
    /// `tab`/`linefeed` must be bound outside the tell block: Ghostty's
    /// dictionary defines a `tab` class that shadows the character constant.
    private static let listSource = """
    set d to tab
    set lf to linefeed
    tell application "Ghostty"
        set theIDs to id of every window
        set theNames to name of every window
        set theCWDs to working directory of every terminal of every window
    end tell
    -- Separate events: a window opening between them would pair the wrong
    -- name with an id, so give up and let the next poll pick it up.
    if (count of theNames) is not (count of theIDs) then error "window list changed"
    if (count of theCWDs) is not (count of theIDs) then error "window list changed"
    set out to ""
    repeat with i from 1 to count of theIDs
        set l to (item i of theIDs) & d & (item i of theNames)
        repeat with c in item i of theCWDs
            set l to l & d & (c as text)
        end repeat
        set out to out & l & lf
    end repeat
    return out
    """

    private static let frontSource = "tell application \"Ghostty\" to get id of front window as text"

    /// Nil when Ghostty can't be asked (not running, Apple event failed) —
    /// callers must not read that as "every window closed".
    static func listWindows() -> [GhosttyWindow]? {
        guard isRunning, let out = run(listSource) else { return nil }
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
        let id = run(frontSource)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (id?.isEmpty ?? true) ? nil : id
    }

    /// Ghostty's `activate window` brings the app forward by itself, and a
    /// `window id` lookup beats scanning with `whose` — together that's ~14ms
    /// instead of ~40ms, the difference between a switch that feels immediate
    /// and one you can see happen.
    static func activate(windowID: String) {
        _ = run("tell application \"Ghostty\" to activate window (window id \"\(escaped(windowID))\")")
    }

    /// Opens a new window and returns its id. Reads the id off the window
    /// `new window` returns: asking for the front window instead can hand back
    /// a different window and bind two workspaces to the same one.
    static func newWindow() -> String? {
        let id = run("""
        tell application "Ghostty"
            activate
            set w to new window
            return id of w as text
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

    /// Compiling a script costs about as much as running it, and these run on
    /// a timer and on every switch, so compiled scripts are kept around. A run
    /// that fails drops its script: a compiled script is bound to the Ghostty
    /// process it was compiled against, which doesn't survive a restart.
    private static var compiled: [String: NSAppleScript] = [:]

    private static func run(_ source: String) -> String? {
        let script = compiled[source] ?? NSAppleScript(source: source)
        compiled[source] = script
        guard let script else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            NSLog("haunts: applescript error: %@", error)
            compiled[source] = nil
            return nil
        }
        return result.stringValue
    }
}
