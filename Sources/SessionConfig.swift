//
//  SessionConfig.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import AppKit
import Foundation

enum MainColor: String, Codable, CaseIterable, Identifiable {
    case red = "Red"
    case orange = "Orange"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case indigo = "Indigo"
    case purple = "Purple"
    case black = "Black"
    case pink = "Pink"

    var id: String { rawValue }

    var nsColor: NSColor {
        switch self {
        case .red: NSColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1.0)
        case .orange: NSColor(red: 0.98, green: 0.55, blue: 0.16, alpha: 1.0)
        case .yellow: NSColor(red: 0.97, green: 0.79, blue: 0.16, alpha: 1.0)
        case .green: NSColor(red: 0.30, green: 0.76, blue: 0.54, alpha: 1.0)
        case .blue: NSColor(red: 0.20, green: 0.56, blue: 0.90, alpha: 1.0)
        case .indigo: NSColor(red: 0.29, green: 0.31, blue: 0.64, alpha: 1.0)
        case .purple: NSColor(red: 0.49, green: 0.36, blue: 0.99, alpha: 1.0)
        case .black: NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        case .pink: NSColor(red: 0.96, green: 0.44, blue: 0.70, alpha: 1.0)
        }
    }

    // Hand-tuned pill colors — uniform darkening turned yellow muddy, so
    // each value is picked for the color family to stay recognizable while
    // keeping contrast with the name label.
    var pillColor: NSColor {
        switch self {
        case .red: NSColor(red: 0.72, green: 0.18, blue: 0.14, alpha: 0.85)
        case .orange: NSColor(red: 0.82, green: 0.38, blue: 0.08, alpha: 0.85)
        case .yellow: NSColor(red: 0.97, green: 0.82, blue: 0.20, alpha: 0.95)
        case .green: NSColor(red: 0.15, green: 0.50, blue: 0.32, alpha: 0.85)
        case .blue: NSColor(red: 0.10, green: 0.38, blue: 0.68, alpha: 0.85)
        case .indigo: NSColor(red: 0.20, green: 0.22, blue: 0.46, alpha: 0.85)
        case .purple: NSColor(red: 0.30, green: 0.22, blue: 0.65, alpha: 0.85)
        case .black: NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 0.92)
        case .pink: NSColor(red: 0.82, green: 0.28, blue: 0.54, alpha: 0.85)
        }
    }

    // Yellow is too bright for white text; use dark text there.
    var pillTextColor: NSColor {
        switch self {
        case .yellow: NSColor(red: 0.20, green: 0.15, blue: 0.05, alpha: 1.0)
        default: .white
        }
    }
}

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
    // Controlling tty (e.g. "ttys036") of this session's claude process. Unique
    // per terminal pane, so it disambiguates two sessions in the same cwd. Empty
    // for sessions registered by an older client — falls back to cwd matching.
    var tty: String

    init(name: String = "New Session", gifPath: String = "", cwdPattern: String = "", order: Int = 0, isAuto: Bool = false, tty: String = "") {
        self.id = UUID()
        self.name = name
        self.gifPath = gifPath
        self.cwdPattern = cwdPattern
        self.order = order
        self.isAuto = isAuto
        self.tty = tty
    }

    enum CodingKeys: String, CodingKey {
        case id, name, gifPath, cwdPattern, order, isAuto, tty
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        gifPath = try c.decode(String.self, forKey: .gifPath)
        cwdPattern = try c.decode(String.self, forKey: .cwdPattern)
        order = try c.decode(Int.self, forKey: .order)
        isAuto = try c.decodeIfPresent(Bool.self, forKey: .isAuto) ?? false
        tty = try c.decodeIfPresent(String.self, forKey: .tty) ?? ""
    }
}

struct AppConfig: Codable {
    var terminal: TerminalApp
    var sessions: [SessionConfig]
    var characterSize: CharacterSize
    var mainColor: MainColor

    init(terminal: TerminalApp = .iterm2, sessions: [SessionConfig] = [], characterSize: CharacterSize = .small, mainColor: MainColor = .purple) {
        self.terminal = terminal
        self.sessions = sessions
        self.characterSize = characterSize
        self.mainColor = mainColor
    }

    enum CodingKeys: String, CodingKey {
        case terminal, sessions, characterSize, mainColor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        terminal = try c.decode(TerminalApp.self, forKey: .terminal)
        sessions = try c.decode([SessionConfig].self, forKey: .sessions)
        characterSize = try c.decodeIfPresent(CharacterSize.self, forKey: .characterSize) ?? .small
        mainColor = try c.decodeIfPresent(MainColor.self, forKey: .mainColor) ?? .purple
    }
}

class ConfigStore: ObservableObject {
    @Published var sessions: [SessionConfig] = []
    @Published var terminal: TerminalApp = .iterm2
    @Published var characterSize: CharacterSize = .small
    @Published var mainColor: MainColor = .purple

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
            mainColor = config.mainColor
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

        let config = AppConfig(terminal: terminal, sessions: sessions, characterSize: characterSize, mainColor: mainColor)
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
