//
//  SessionConfig.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import Foundation

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

class ConfigStore: ObservableObject {
    @Published var sessions: [SessionConfig] = []

    var onChange: (() -> Void)?

    static let dirPath = NSString("~/.claude-monitor").expandingTildeInPath
    static let configPath = (NSString("~/.claude-monitor/config.json").expandingTildeInPath)

    init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.configPath)),
              var decoded = try? JSONDecoder().decode([SessionConfig].self, from: data)
        else { return }

        decoded.sort { $0.order < $1.order }
        sessions = decoded
    }

    func save() {
        for i in sessions.indices {
            sessions[i].order = i
        }

        try? FileManager.default.createDirectory(
            atPath: Self.dirPath,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(sessions) else { return }
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
