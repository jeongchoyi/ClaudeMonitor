//
//  SessionConfig.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import Foundation

enum CharacterSize: String, Codable, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    var scale: CGFloat {
        switch self {
        case .small: 1.0
        case .medium: 1.3
        case .large: 1.6
        }
    }
}

enum TerminalApp: String, Codable, CaseIterable, Identifiable {
    case iterm2 = "iTerm2"
    case terminal = "Terminal"
    case cmux = "cmux"
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
        case .cmux: "com.cmuxterm.app"
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
    var isAuto: Bool

    init(name: String = "New Session", gifPath: String = "", cwdPattern: String = "", order: Int = 0, isAuto: Bool = false) {
        self.id = UUID()
        self.name = name
        self.gifPath = gifPath
        self.cwdPattern = cwdPattern
        self.order = order
        self.isAuto = isAuto
    }

    enum CodingKeys: String, CodingKey {
        case id, name, gifPath, cwdPattern, order, isAuto
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        gifPath = try c.decode(String.self, forKey: .gifPath)
        cwdPattern = try c.decode(String.self, forKey: .cwdPattern)
        order = try c.decode(Int.self, forKey: .order)
        isAuto = try c.decodeIfPresent(Bool.self, forKey: .isAuto) ?? false
    }
}

struct AppConfig: Codable {
    var terminal: TerminalApp
    var sessions: [SessionConfig]
    var characterSize: CharacterSize

    init(terminal: TerminalApp = .iterm2, sessions: [SessionConfig] = [], characterSize: CharacterSize = .small) {
        self.terminal = terminal
        self.sessions = sessions
        self.characterSize = characterSize
    }

    enum CodingKeys: String, CodingKey {
        case terminal, sessions, characterSize
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        terminal = try c.decode(TerminalApp.self, forKey: .terminal)
        sessions = try c.decode([SessionConfig].self, forKey: .sessions)
        characterSize = try c.decodeIfPresent(CharacterSize.self, forKey: .characterSize) ?? .small
    }
}

class ConfigStore: ObservableObject {
    @Published var sessions: [SessionConfig] = []
    @Published var terminal: TerminalApp = .iterm2
    @Published var characterSize: CharacterSize = .small

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
            characterSize = config.characterSize
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

        let config = AppConfig(terminal: terminal, sessions: sessions, characterSize: characterSize)
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
