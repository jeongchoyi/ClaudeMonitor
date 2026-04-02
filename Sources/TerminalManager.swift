//
//  TerminalManager.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import AppKit

enum TerminalManager {

    static func activate(forPath path: String) {
        if let app = runningApp(bundleID: "com.googlecode.iterm2") {
            app.activate()
            activateITermTab(forPath: path)
        } else if let app = runningApp(bundleID: "com.apple.Terminal") {
            app.activate()
            activateTerminalTab(forPath: path)
        }
    }

    // MARK: - Private

    private static func runningApp(bundleID: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleID
        }
    }

    private static func activateITermTab(forPath path: String) {
        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
        let folderName = (path as NSString).lastPathComponent.replacingOccurrences(of: "\"", with: "\\\"")

        // Match by: session name, tab name, or path variable
        // Use folder name as fallback since full path might not appear in title
        let script = """
        tell application "iTerm2"
            set targetPath to "\(escapedPath)"
            set targetFolder to "\(folderName)"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        try
                            set sName to name of s
                            if sName contains targetPath or sName contains targetFolder then
                                select t
                                select s
                                set index of w to 1
                                return
                            end if
                        end try
                    end repeat
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    private static func activateTerminalTab(forPath path: String) {
        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
        let folderName = (path as NSString).lastPathComponent.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Terminal"
            set targetPath to "\(escapedPath)"
            set targetFolder to "\(folderName)"
            repeat with w in windows
                repeat with t in tabs of w
                    try
                        set tName to name of t
                        if tName contains targetPath or tName contains targetFolder then
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
