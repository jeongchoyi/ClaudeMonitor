//
//  AppDelegate.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    private var overlayWindow: OverlayWindow!
    private var contextMenu: NSMenu!
    private var server: NotificationServer!
    private var characterView: CharacterView!
    private var configStore: ConfigStore!
    private var configWindow: NSWindow?

    private var bubbleShownAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configStore = ConfigStore()
        configStore.onChange = { [weak self] in
            self?.reloadOverlay()
        }

        loadAppIcon()
        setupOverlayWindow()
        setupContextMenu()
        setupServer()
        startFocusMonitor()
        startSessionCleanup()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func loadAppIcon() {
        let iconPath = (ConfigStore.dirPath as NSString).appendingPathComponent("icon.png")
        if let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
        }
    }

    // MARK: - Setup

    private func setupOverlayWindow() {
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen = NSScreen.screens.first {
            $0.frame.contains(mouseLocation)
        } ?? NSScreen.main!
        let screenFrame = currentScreen.visibleFrame

        let windowSize = overlaySize()
        let windowOrigin = NSPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY + screenFrame.height * 0.25
        )

        overlayWindow = OverlayWindow(
            contentRect: NSRect(origin: windowOrigin, size: windowSize)
        )

        characterView = CharacterView(
            frame: NSRect(origin: .zero, size: windowSize)
        )
        characterView.sizeScale = configStore.characterSize.scale
        characterView.onBubbleClicked = { [weak self] sessionPath in
            TerminalManager.activate(forPath: sessionPath)
            self?.characterView.hideBubble()
        }
        TerminalManager.terminalApp = configStore.terminal
        characterView.updateSessions(configStore.sessions)

        overlayWindow.contentView = characterView
        overlayWindow.orderFrontRegardless()
    }

    private func setupContextMenu() {
        contextMenu = NSMenu()
        contextMenu.addItem(NSMenuItem(
            title: "New Session",
            action: #selector(newSession),
            keyEquivalent: ""
        ))
        contextMenu.addItem(.separator())
        contextMenu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ""
        ))
        contextMenu.addItem(NSMenuItem(
            title: "Reset Position",
            action: #selector(resetPosition),
            keyEquivalent: ""
        ))
        contextMenu.addItem(.separator())
        contextMenu.addItem(NSMenuItem(
            title: "Quit ClaudeMonitor",
            action: #selector(quit),
            keyEquivalent: ""
        ))

        characterView.onRightClick = { [weak self] event in
            guard let self else { return }
            NSMenu.popUpContextMenu(self.contextMenu, with: event, for: self.characterView)
        }
    }

    private func setupServer() {
        server = NotificationServer(
            port: 9877,
            onNotify: { [weak self] notification in
                DispatchQueue.main.async {
                    self?.handleNotification(notification)
                }
            },
            onRegister: { [weak self] name, cwd, gifPath, isAuto in
                DispatchQueue.main.async {
                    self?.registerSession(name: name, cwd: cwd, gifPath: gifPath, isAuto: isAuto)
                }
            }
        )
    }

    private func registerSession(name: String, cwd: String, gifPath: String, isAuto: Bool) {
        if let idx = configStore.sessions.firstIndex(where: {
            $0.cwdPattern.caseInsensitiveCompare(cwd) == .orderedSame
        }) {
            if isAuto && !configStore.sessions[idx].isAuto {
                configStore.sessions[idx].isAuto = true
                configStore.save()
            }
            return
        }

        var session = SessionConfig(
            name: name.isEmpty ? (cwd as NSString).lastPathComponent : name,
            cwdPattern: cwd,
            order: configStore.sessions.count,
            isAuto: isAuto
        )
        if !gifPath.isEmpty { session.gifPath = gifPath }
        configStore.sessions.append(session)
        configStore.save()
    }

    // MARK: - Notification handling

    private func handleNotification(_ notification: SessionNotification) {
        bubbleShownAt = Date()
        characterView.showBubble(
            message: notification.message,
            sessionPath: notification.sessionPath,
            name: notification.name
        )
        NSSound(named: NSSound.Name("Pop"))?.play()
    }

    // MARK: - Overlay management

    private func overlaySize() -> NSSize {
        let scale = configStore.characterSize.scale
        let count = max(configStore.sessions.count, 1)
        let width = max(CGFloat(count) * 80 * scale + 40, 300)
        return NSSize(width: width, height: 220 * scale)
    }

    private func reloadOverlay() {
        TerminalManager.terminalApp = configStore.terminal
        characterView.sizeScale = configStore.characterSize.scale
        characterView.updateSessions(configStore.sessions)

        let count = max(configStore.sessions.count, 1)
        let slotWidth = characterView.slotWidth
        let newWidth = max(CGFloat(count) * slotWidth + 40, 300)
        let newHeight = 220 * configStore.characterSize.scale

        var frame = overlayWindow.frame
        let rightEdge = frame.maxX
        let topEdge = frame.maxY
        frame.size.width = newWidth
        frame.size.height = newHeight
        frame.origin.x = rightEdge - newWidth
        frame.origin.y = topEdge - newHeight
        overlayWindow.setFrame(frame, display: true, animate: true)

        characterView.frame = NSRect(origin: .zero, size: frame.size)
    }

    // MARK: - Auto-dismiss bubble when user switches to terminal

    private func startFocusMonitor() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self, self.characterView.hasBubble else { return }
            // Don't auto-dismiss within 8 seconds so user can see the notification
            if let shownAt = self.bubbleShownAt, Date().timeIntervalSince(shownAt) < 8 { return }
            guard let frontApp = NSWorkspace.shared.frontmostApplication,
                  let bid = frontApp.bundleIdentifier else { return }
            let termBID = self.configStore.terminal.bundleID
            if (!termBID.isEmpty && bid == termBID) ||
               (self.configStore.terminal == .tmux && (
                   bid.contains("iterm2") || bid.contains("Terminal") ||
                   bid.contains("warp") || bid.contains("ghostty") ||
                   bid.contains("kitty") || bid.contains("alacritty")
               )) {
                self.characterView.hideBubble()
            }
        }
    }

    // MARK: - Auto-cleanup dead sessions

    private func startSessionCleanup() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.cleanupDeadSessions()
        }
    }

    private func cleanupDeadSessions() {
        let autoSessions = configStore.sessions.filter { $0.isAuto }
        guard !autoSessions.isEmpty else { return }

        let output = TerminalManager.shell(
            "ps -eo pid,comm 2>/dev/null | awk '/claude/{print $1}' | while read pid; do lsof -a -p $pid -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-; done"
        )
        let activeCWDs = output.split(separator: "\n").map(String.init)

        var changed = false
        for session in autoSessions {
            let alive = activeCWDs.contains {
                $0.caseInsensitiveCompare(session.cwdPattern) == .orderedSame
            }
            if !alive {
                configStore.sessions.removeAll { $0.id == session.id }
                changed = true
            }
        }
        if changed {
            configStore.save()
        }
    }

    // MARK: - Settings window

    @objc private func openSettings() {
        if let existing = configWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let view = ConfigView(store: configStore)
        let controller = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: controller)
        window.title = "ClaudeMonitor Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            NSApp.setActivationPolicy(.accessory)
            self?.configWindow = nil
        }

        configWindow = window
    }

    // MARK: - Actions

    @objc private func newSession() {
        let script = """
        tell application "iTerm2"
            activate
            tell current window
                create tab with default profile
            end tell
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if error != nil {
            // iTerm2 not running, open new window
            NSWorkspace.shared.launchApplication("iTerm")
        }
    }

    @objc private func resetPosition() {
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen = NSScreen.screens.first {
            $0.frame.contains(mouseLocation)
        } ?? NSScreen.main!
        let screenFrame = currentScreen.visibleFrame
        let size = overlayWindow.frame.size
        overlayWindow.setFrameOrigin(NSPoint(
            x: screenFrame.maxX - size.width - 20,
            y: screenFrame.minY + 20
        ))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
