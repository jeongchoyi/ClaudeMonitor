//
//  SessionConfig.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import Foundation

enum TerminalApp: String, Codable, CaseIterable, Identifiable {
    case iterm2 = "iTerm2"
    case terminal = "Terminal"
    case tmux = "tmux"
    case warp = "Warp"
    case ghostty = "Ghostty"
    case kitty = "Kitty"
    case alacritty = "Alacritty"

    var id: String { rawValue }

    var bundleID: String {
        switch self {
        case .iterm2: "com.googlecode.iterm2"
        case .terminal: "com.apple.Terminal"
        case .tmux: "" // tmux runs inside another terminal
        case .warp: "dev.warp.Warp-Stable"
        case .ghostty: "com.mitchellh.ghostty"
        case .kitty: "net.kovidgoyal.kitty"
        case .alacritty: "org.alacritty"
        }
    }
}

struct SessionConfig: Codable, Identifiable {
    var id: UUID
    var name: String
    var gifPath: String
    var cwdPattern: String
    var order: Int

    init(name: String = "New Session", gifPath: String = "", cwdPattern: String = "", order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.gifPath = gifPath
        self.cwdPattern = cwdPattern
        self.order = order
    }
}

struct AppConfig: Codable {
    var terminal: TerminalApp
    var sessions: [SessionConfig]

    init(terminal: TerminalApp = .iterm2, sessions: [SessionConfig] = []) {
        self.terminal = terminal
        self.sessions = sessions
    }
}

class ConfigStore: ObservableObject {
    @Published var sessions: [SessionConfig] = []
    @Published var terminal: TerminalApp = .iterm2

    var onChange: (() -> Void)?

    static let dirPath = NSString("~/.claude-monitor").expandingTildeInPath
    static let configPath = NSString("~/.claude-monitor/config.json").expandingTildeInPath

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.configPath)) else { return }

        // Try new format (AppConfig) first, then legacy (array of sessions)
        if let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
            terminal = config.terminal
            sessions = config.sessions.sorted { $0.order < $1.order }
        } else if var legacy = try? JSONDecoder().decode([SessionConfig].self, from: data) {
            legacy.sort { $0.order < $1.order }
            sessions = legacy
        }
    }

    func save() {
        for i in sessions.indices {
            sessions[i].order = i
        }

        try? FileManager.default.createDirectory(
            atPath: Self.dirPath,
            withIntermediateDirectories: true
        )

        let config = AppConfig(terminal: terminal, sessions: sessions)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: URL(fileURLWithPath: Self.configPath))

        onChange?()
    }

    func add() {
        sessions.append(SessionConfig(
            name: "Session \(sessions.count + 1)",
            order: sessions.count
        ))
    }

    func remove(_ id: UUID) {
        sessions.removeAll { $0.id == id }
    }

    func moveUp(_ id: UUID) {
        guard let i = sessions.firstIndex(where: { $0.id == id }), i > 0 else { return }
        sessions.swapAt(i, i - 1)
    }

    func moveDown(_ id: UUID) {
        guard let i = sessions.firstIndex(where: { $0.id == id }), i < sessions.count - 1 else { return }
        sessions.swapAt(i, i + 1)
    }
}
