//
//  NotificationServer.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import Foundation
import Network

struct SessionNotification {
    let sessionPath: String
    let message: String
    let name: String?
}

class NotificationServer {

    private let listener: NWListener
    private let onNotify: (SessionNotification) -> Void
    private let onRegister: (String, String, String, Bool) -> Void // name, cwd, gifPath, isAuto

    init(port: UInt16,
         onNotify: @escaping (SessionNotification) -> Void,
         onRegister: @escaping (String, String, String, Bool) -> Void)
    {
        self.onNotify = onNotify
        self.onRegister = onRegister
        self.listener = try! NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[ClaudeMonitor] Listening on port \(port)")
            case .failed(let error):
                print("[ClaudeMonitor] Server failed: \(error)")
            default:
                break
            }
        }

        listener.start(queue: .main)
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self else { connection.cancel(); return }

            var responseBody = "{\"status\":\"ok\"}"
            var action: (() -> Void)?

            if let data, let request = String(data: data, encoding: .utf8) {
                (responseBody, action) = self.route(request)
            }

            let http = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(responseBody.utf8.count)\r\nConnection: close\r\n\r\n\(responseBody)"
            connection.send(content: http.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })

            action?()
        }
    }

    private func route(_ request: String) -> (String, (() -> Void)?) {
        let firstLine = String(request.prefix(while: { $0 != "\r" }))
        let parts = firstLine.split(separator: " ")
        let path = parts.count > 1 ? String(parts[1]) : ""

        guard let bodyRange = request.range(of: "\r\n\r\n") else {
            return ("{\"error\":\"no body\"}", nil)
        }
        let body = String(request[bodyRange.upperBound...])
        guard let jsonData = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            return ("{\"error\":\"invalid json\"}", nil)
        }

        switch path {
        case "/notify":
            if let n = parseNotification(json) {
                return ("{\"status\":\"ok\"}", { self.onNotify(n) })
            }
            return ("{\"error\":\"bad notification\"}", nil)

        case "/register":
            let name = json["name"] as? String ?? ""
            let cwd = json["cwd"] as? String ?? ""
            let gifPath = json["gifPath"] as? String ?? ""
            let isAuto = json["isAuto"] as? Bool ?? false
            guard !cwd.isEmpty else {
                return ("{\"error\":\"cwd required\"}", nil)
            }
            let safeName = name.replacingOccurrences(of: "\"", with: "'")
            return ("{\"status\":\"registered\",\"name\":\"\(safeName)\"}", {
                self.onRegister(name, cwd, gifPath, isAuto)
            })

        default:
            return ("{\"error\":\"unknown endpoint: \(path)\"}", nil)
        }
    }

    private func parseNotification(_ json: [String: Any]) -> SessionNotification? {
        let sessionPath = json["cwd"] as? String ?? "unknown"
        let tool = json["tool"] as? String ?? ""
        let project = (sessionPath as NSString).lastPathComponent
        let message = json["message"] as? String
            ?? (tool.isEmpty ? project : "\(project): \(tool)")
        let name = json["name"] as? String
        return SessionNotification(sessionPath: sessionPath, message: message, name: name)
    }
}
