//
//  TerminalManager.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import AppKit

enum TerminalManager {

    static var terminalApp: TerminalApp = .iterm2

    static func activate(forPath path: String, tty: String = "") {
        if terminalApp == .tmux {
            activateTmuxSession(forPath: path)
            return
        }

        let bundleID = terminalApp.bundleID
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleID
        }) else { return }

        // If our Settings window is keeping ClaudeMonitor frontmost, target
        // apps won't activate. Yield focus before requesting activation.
        if NSApp.isActive {
            NSApp.deactivate()
        }
        app.activate(options: [.activateAllWindows])

        switch terminalApp {
        case .iterm2:
            activateITermTab(forTTY: tty, path: path)
        case .terminal:
            activateTerminalTab(forPath: path)
        default:
            break
        }
    }

    // MARK: - iTerm2

    // Prefer an exact tty match (unique per pane). Fall back to resolving the
    // tab by process cwd when no tty was captured at registration (legacy).
    private static func activateITermTab(forTTY ttyTarget: String, path: String) {
        let listScript = """
        tell application "iTerm2"
            set output to ""
            set wIdx to 0
            repeat with w in windows
                set wIdx to wIdx + 1
                set tIdx to 0
                repeat with t in tabs of w
                    set tIdx to tIdx + 1
                    repeat with s in sessions of t
                        try
                            set output to output & wIdx & "," & tIdx & "," & (tty of s) & linefeed
                        end try
                    end repeat
                end repeat
            end repeat
            return output
        end tell
        """
        guard let sessions = runAppleScript(listScript), !sessions.isEmpty else { return }

        for line in sessions.split(separator: "\n") {
            let parts = line.split(separator: ",")
            guard parts.count >= 3 else { continue }
            let wIdx = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let tIdx = String(parts[1]).trimmingCharacters(in: .whitespaces)
            let ttyName = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "/dev/", with: "")

            guard !ttyName.isEmpty else { continue }

            let matched: Bool
            if !ttyTarget.isEmpty {
                matched = (ttyName == ttyTarget)
            } else if !path.isEmpty {
                let check = shell("ps -t \(ttyName) -o pid= 2>/dev/null | while read pid; do lsof -a -p $pid -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-; done")
                matched = check.range(of: path, options: .caseInsensitive) != nil
            } else {
                matched = false
            }

            if matched {
                let selectScript = """
                tell application "iTerm2"
                    activate
                    set w to item \(wIdx) of windows
                    set t to item \(tIdx) of tabs of w
                    select t
                    set index of w to 1
                end tell
                """
                runAppleScript(selectScript)
                return
            }
        }
    }

    // MARK: - Terminal.app

    private static func activateTerminalTab(forPath path: String) {
        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
        let folderName = (path as NSString).lastPathComponent

        let script = """
        tell application "Terminal"
            activate
            repeat with w in windows
                repeat with t in tabs of w
                    try
                        set tName to name of t
                        if tName contains "\(escapedPath)" or tName contains "\(folderName)" then
                            set selected tab of w to t
                            set index of w to 1
                            return
                        end if
                    end try
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    // MARK: - tmux

    private static func activateTmuxSession(forPath path: String) {
        let folderName = (path as NSString).lastPathComponent

        // List all tmux panes with their CWDs
        // Format: session:window.pane,cwd
        let list = shell("tmux list-panes -a -F '#{session_name}:#{window_index},#{pane_current_path}' 2>/dev/null")
        guard !list.isEmpty else { return }

        for line in list.split(separator: "\n") {
            let parts = line.split(separator: ",", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let target = String(parts[0]) // session:window
            let cwd = String(parts[1])

            if cwd.range(of: path, options: .caseInsensitive) != nil || cwd.hasSuffix(folderName) {
                shell("tmux select-window -t '\(target)' 2>/dev/null")
                // Also bring the terminal app to front
                if let frontTerminal = NSWorkspace.shared.runningApplications.first(where: {
                    guard let bid = $0.bundleIdentifier else { return false }
                    return bid.contains("iterm2") || bid.contains("Terminal") ||
                           bid.contains("warp") || bid.contains("ghostty") ||
                           bid.contains("kitty") || bid.contains("alacritty")
                }) {
                    frontTerminal.activate()
                }
                return
            }
        }
    }

    // MARK: - Helpers

    @discardableResult
    static func shell(_ command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    @discardableResult
    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)

        if let error {
            print("[ClaudeMonitor] AppleScript error: \(error)")
        }

        return result?.stringValue
    }
}
