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

    private var debounceTimer: Timer?
    private var pendingNotification: SessionNotification?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configStore = ConfigStore()
        configStore.onChange = { [weak self] in
            self?.reloadOverlay()
        }

        setupOverlayWindow()
        setupContextMenu()
        setupServer()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.accessory)
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
        characterView.onBubbleClicked = { [weak self] sessionPath in
            TerminalManager.activate(forPath: sessionPath)
            self?.characterView.hideBubble()
        }
        characterView.updateSessions(configStore.sessions)

        overlayWindow.contentView = characterView
        overlayWindow.orderFrontRegardless()
    }

    private func setupContextMenu() {
        contextMenu = NSMenu()
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
            onRegister: { [weak self] name, cwd, gifPath in
                DispatchQueue.main.async {
                    self?.registerSession(name: name, cwd: cwd, gifPath: gifPath)
                }
            }
        )
    }

    private func registerSession(name: String, cwd: String, gifPath: String) {
        guard !configStore.sessions.contains(where: { $0.cwdPattern == cwd }) else { return }

        var session = SessionConfig(
            name: name.isEmpty ? (cwd as NSString).lastPathComponent : name,
            cwdPattern: cwd,
            order: configStore.sessions.count
        )
        if !gifPath.isEmpty { session.gifPath = gifPath }
        configStore.sessions.append(session)
        configStore.save()
    }

    // MARK: - Notification handling with debounce

    private func handleNotification(_ notification: SessionNotification) {
        pendingNotification = notification
        debounceTimer?.invalidate()

        debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self, let pending = self.pendingNotification else { return }
            self.characterView.showBubble(
                message: pending.message,
                sessionPath: pending.sessionPath,
                name: pending.name
            )
            NSSound(named: NSSound.Name("Pop"))?.play()
        }
    }

    // MARK: - Overlay management

    private func overlaySize() -> NSSize {
        let count = max(configStore.sessions.count, 1)
        let width = max(CGFloat(count) * 80 + 40, 300)
        return NSSize(width: width, height: 220)
    }

    private func reloadOverlay() {
        characterView.updateSessions(configStore.sessions)

        let count = max(configStore.sessions.count, 1)
        let slotWidth = characterView.slotWidth
        let newWidth = max(CGFloat(count) * slotWidth + 40, 300)

        var frame = overlayWindow.frame
        let rightEdge = frame.maxX
        frame.size.width = newWidth
        frame.origin.x = rightEdge - newWidth
        overlayWindow.setFrame(frame, display: true, animate: true)

        characterView.frame = NSRect(origin: .zero, size: frame.size)
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
