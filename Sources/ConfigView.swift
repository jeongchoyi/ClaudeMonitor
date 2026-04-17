//
//  ConfigView.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import SwiftUI
import UniformTypeIdentifiers

struct ConfigView: View {
    @ObservedObject var store: ConfigStore

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ClaudeMonitor")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Sessions")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()

            // Terminal selector
            HStack {
                Text("Terminal")
                    .foregroundColor(.secondary)
                Picker("", selection: $store.terminal) {
                    ForEach(TerminalApp.allCases) { app in
                        Text(app.rawValue).tag(app)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Character size selector
            HStack {
                Text("Size")
                    .foregroundColor(.secondary)
                Picker("", selection: $store.characterSize) {
                    ForEach(CharacterSize.allCases) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            // Color selector
            HStack(spacing: 8) {
                Text("Color")
                    .foregroundColor(.secondary)
                ForEach(MainColor.allCases) { color in
                    Circle()
                        .fill(Color(nsColor: color.nsColor))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.4), lineWidth: 1)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.accentColor, lineWidth: 2)
                                .opacity(store.mainColor == color ? 1 : 0)
                                .padding(-3)
                        )
                        .onTapGesture { store.mainColor = color }
                        .help(color.rawValue)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Session list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($store.sessions) { $session in
                        SessionRowView(
                            session: $session,
                            mainColor: store.mainColor,
                            onMoveUp: { store.moveUp(session.id) },
                            onMoveDown: { store.moveDown(session.id) },
                            onDelete: { store.remove(session.id) }
                        )
                    }

                    if store.sessions.isEmpty {
                        VStack(spacing: 8) {
                            Text("No sessions yet")
                                .font(.headline)
                            Text("Add a session to get started")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button(action: { store.add() }) {
                    Label("Add Session", systemImage: "plus")
                }

                Spacer()

                Button("Save") {
                    store.save()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 540, height: 500)
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    @Binding var session: SessionConfig
    let mainColor: MainColor
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // GIF preview
            gifPreview
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(nsColor: mainColor.nsColor).opacity(0.3), lineWidth: 2))

            // Fields
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text("Name")
                        .frame(width: 36, alignment: .trailing)
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Session name", text: $session.name)
                        .textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 8) {
                    Text("Path")
                        .frame(width: 36, alignment: .trailing)
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Working directory (e.g. /Users/me/project)", text: $session.cwdPattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
                HStack(spacing: 8) {
                    Text("GIF")
                        .frame(width: 36, alignment: .trailing)
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Avatar image path", text: $session.gifPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button(action: pickGif) {
                        Image(systemName: "folder")
                    }
                }
            }

            // Order & delete controls
            VStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Spacer().frame(height: 4)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var gifPreview: some View {
        if !session.gifPath.isEmpty,
           let image = NSImage(contentsOfFile: (session.gifPath as NSString).expandingTildeInPath)
        {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Circle()
                .fill(Color(nsColor: mainColor.nsColor))
                .overlay(
                    Text(String(session.name.prefix(1)).uppercased())
                        .font(.title3.bold())
                        .foregroundColor(.white)
                )
        }
    }

    private func pickGif() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif, .png, .jpeg]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "Select avatar image (GIF for animation)"
        if panel.runModal() == .OK, let url = panel.url {
            let avatarsDir = (ConfigStore.dirPath as NSString).appendingPathComponent("avatars")
            try? FileManager.default.createDirectory(atPath: avatarsDir, withIntermediateDirectories: true)

            let dest = (avatarsDir as NSString).appendingPathComponent(
                session.id.uuidString + "." + url.pathExtension
            )
            try? FileManager.default.removeItem(atPath: dest)
            try? FileManager.default.copyItem(atPath: url.path, toPath: dest)

            session.gifPath = dest
        }
    }
}
