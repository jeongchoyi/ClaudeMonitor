//
//  CharacterView.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import AppKit

class CharacterView: NSView {

    var onBubbleClicked: ((String) -> Void)?
    var onRightClick: ((NSEvent) -> Void)?

    // Sessions
    private var sessions: [SessionConfig] = []
    private var avatarFrames: [UUID: [NSImage]] = [:]
    private var avatarFrameIndices: [UUID: Int] = [:]
    private var avatarData: [UUID: Data] = [:]
    private var gifTimer: Timer?

    // Bubble
    private var bubbleView: BubbleView?
    private var activeSessionID: UUID?
    private var activeSessionPath = ""

    // Animation
    private var bounceSessionID: UUID?
    private var bounceOffset: CGFloat = 0
    private var isBouncing = false
    private var eyeOffset: CGFloat = 0

    // Layout
    var sizeScale: CGFloat = 1.0 {
        didSet {
            guard oldValue != sizeScale else { return }
            needsDisplay = true
        }
    }
    var mainColor: MainColor = .purple {
        didSet {
            guard oldValue != mainColor else { return }
            needsDisplay = true
        }
    }
    var slotWidth: CGFloat { 80 * sizeScale }
    private var characterSize: CGFloat { 56 * sizeScale }
    private var characterBaseY: CGFloat { 24 * sizeScale }

    private let colors: [NSColor] = [
        NSColor(red: 0.486, green: 0.361, blue: 0.988, alpha: 1.0),
        NSColor(red: 0.204, green: 0.596, blue: 0.859, alpha: 1.0),
        NSColor(red: 0.306, green: 0.765, blue: 0.545, alpha: 1.0),
        NSColor(red: 0.945, green: 0.553, blue: 0.231, alpha: 1.0),
        NSColor(red: 0.878, green: 0.349, blue: 0.349, alpha: 1.0),
    ]

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.drawsAsynchronously = true
        startIdleAnimation()
        startGifAnimation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    var hasBubble: Bool { bubbleView != nil }

    func updateSessions(_ newSessions: [SessionConfig]) {
        sessions = newSessions
        reloadAvatars()
        needsDisplay = true
    }

    func showBubble(message: String, sessionPath: String, name: String? = nil) {
        let matched = sessions.first { !$0.cwdPattern.isEmpty && sessionPath.contains($0.cwdPattern) }
        activeSessionID = matched?.id ?? sessions.first?.id
        activeSessionPath = sessionPath

        bubbleView?.removeFromSuperview()

        let bubble = BubbleView(
            message: message,
            borderColor: mainColor.nsColor.withAlphaComponent(0.85)
        )
        let bubbleSize = bubble.intrinsicContentSize

        let slotIndex: Int
        if let id = activeSessionID {
            slotIndex = sessions.firstIndex(where: { $0.id == id }) ?? 0
        } else {
            slotIndex = 0
        }

        let cx = slotCenterX(for: slotIndex)
        let bubbleX = max(4, min(cx - bubbleSize.width / 2, bounds.width - bubbleSize.width - 4))

        bubble.frame = NSRect(
            x: bubbleX,
            y: characterBaseY + characterSize + 20,
            width: bubbleSize.width,
            height: bubbleSize.height
        )
        bubble.tailX = cx - bubbleX
        bubble.onClick = { [weak self] in
            guard let self else { return }
            self.onBubbleClicked?(self.activeSessionPath)
        }

        bubble.alphaValue = 0
        addSubview(bubble)
        bubbleView = bubble

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            bubble.animator().alphaValue = 1
        }

        bounceSessionID = activeSessionID
        doBounce()
    }

    func hideBubble() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            bubbleView?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.bubbleView?.removeFromSuperview()
            self?.bubbleView = nil
            self?.activeSessionID = nil
        })
    }

    // MARK: - Hit Testing

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let bubble = bubbleView {
            let p = convert(point, to: bubble)
            if bubble.bounds.contains(p) {
                return bubble
            }
        }

        let count = max(sessions.count, 1)
        for i in 0..<count {
            let cx = slotCenterX(for: i)
            let cy = characterBaseY + characterSize / 2
            let dx = point.x - cx
            let dy = point.y - cy
            if sqrt(dx * dx + dy * dy) <= characterSize / 2 + 10 {
                return self
            }
        }

        return nil
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        if sessions.isEmpty {
            let cx = bounds.midX
            let by = characterBaseY + (isBouncing ? bounceOffset : 0)
            drawFaceCharacter(in: context, centerX: cx, baseY: by, color: colors[0])
        } else {
            for (index, session) in sessions.enumerated() {
                drawSession(session, at: index, in: context)
            }
        }
    }

    private func drawSession(_ session: SessionConfig, at index: Int, in context: CGContext) {
        let cx = slotCenterX(for: index)
        let sessionBouncing = isBouncing && bounceSessionID == session.id
        let by = characterBaseY + (sessionBouncing ? bounceOffset : 0)

        if let frames = avatarFrames[session.id], !frames.isEmpty {
            let fi = avatarFrameIndices[session.id] ?? 0
            drawAvatar(frames[fi], centerX: cx, baseY: by)
        } else {
            drawColorCircle(
                centerX: cx,
                baseY: by,
                color: colors[index % colors.count],
                initial: String(session.name.prefix(1))
            )
        }

        drawNameLabel(session.name, centerX: cx, baseY: by)

    }

    // MARK: - Drawing Helpers

    private func drawAvatar(_ image: NSImage, centerX: CGFloat, baseY: CGFloat) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        // Aspect fit within characterSize
        let scale = min(characterSize / imageSize.width, characterSize / imageSize.height)
        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale

        let rect = NSRect(
            x: centerX - drawWidth / 2,
            y: baseY + (characterSize - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )

        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    private func drawColorCircle(centerX: CGFloat, baseY: CGFloat, color: NSColor, initial: String) {
        let rect = NSRect(
            x: centerX - characterSize / 2,
            y: baseY,
            width: characterSize,
            height: characterSize
        )

        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 6
        shadow.set()
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: characterSize * 0.38, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style,
        ]
        let text = initial.uppercased() as NSString
        let textSize = text.size(withAttributes: attrs)
        text.draw(in: NSRect(
            x: centerX - textSize.width / 2,
            y: baseY + (characterSize - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        ), withAttributes: attrs)
    }

    private func drawFaceCharacter(in context: CGContext, centerX: CGFloat, baseY: CGFloat, color: NSColor) {
        let size = characterSize
        let bodyRect = NSRect(x: centerX - size / 2, y: baseY, width: size, height: size)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        color.setFill()
        NSBezierPath(ovalIn: bodyRect).fill()
        context.restoreGState()

        let eyeY = baseY + size * 0.55
        let eyeSpacing = size * 0.143
        let eyeSize = size * 0.196
        let pupilSize = size * 0.089

        for side: CGFloat in [-1, 1] {
            let eyeX = centerX + side * eyeSpacing
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: eyeX - eyeSize / 2, y: eyeY, width: eyeSize, height: eyeSize)).fill()
            NSColor(red: 0.2, green: 0.15, blue: 0.35, alpha: 1.0).setFill()
            NSBezierPath(ovalIn: NSRect(
                x: eyeX - pupilSize / 2 + eyeOffset,
                y: eyeY + (eyeSize - pupilSize) / 2,
                width: pupilSize,
                height: pupilSize
            )).fill()
        }

        let smileOffset = size * 0.107
        let smileControlOffset = size * 0.054
        let smilePath = NSBezierPath()
        smilePath.move(to: NSPoint(x: centerX - smileOffset, y: baseY + size * 0.38))
        smilePath.curve(
            to: NSPoint(x: centerX + smileOffset, y: baseY + size * 0.38),
            controlPoint1: NSPoint(x: centerX - smileControlOffset, y: baseY + size * 0.28),
            controlPoint2: NSPoint(x: centerX + smileControlOffset, y: baseY + size * 0.28)
        )
        NSColor.white.setStroke()
        smilePath.lineWidth = 1.5 * sizeScale
        smilePath.stroke()
    }

    private func drawNameLabel(_ name: String, centerX: CGFloat, baseY: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let fontSize = 9 * sizeScale
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: mainColor.pillTextColor,
            .paragraphStyle: style,
        ]
        let text = name as NSString
        let textSize = text.size(withAttributes: attrs)
        let pillPadX = 5 * sizeScale
        let pillPadY = 4 * sizeScale
        let gapY = 6 * sizeScale

        let pillRect = NSRect(
            x: centerX - textSize.width / 2 - pillPadX,
            y: baseY - textSize.height - gapY,
            width: textSize.width + pillPadX * 2,
            height: textSize.height + pillPadY
        )
        mainColor.pillColor.setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: 7, yRadius: 7).fill()

        text.draw(in: NSRect(
            x: centerX - textSize.width / 2,
            y: baseY - textSize.height - gapY + pillPadY / 2,
            width: textSize.width,
            height: textSize.height
        ), withAttributes: attrs)
    }

    // MARK: - Layout

    private func slotCenterX(for index: Int) -> CGFloat {
        let count = max(sessions.count, 1)
        let totalWidth = CGFloat(count) * slotWidth
        let startX = (bounds.width - totalWidth) / 2
        return startX + CGFloat(index) * slotWidth + slotWidth / 2
    }

    // MARK: - Avatar Loading

    private func reloadAvatars() {
        avatarFrames.removeAll()
        avatarFrameIndices.removeAll()
        avatarData.removeAll()

        for session in sessions {
            guard !session.gifPath.isEmpty else { continue }
            let path = (session.gifPath as NSString).expandingTildeInPath
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { continue }

            avatarData[session.id] = data // keep data alive

            let frameCount = min(CGImageSourceGetCount(source), 200)
            var frames: [NSImage] = []
            // Accumulate frames to handle delta/dispose correctly
            let canvasW = 128
            let canvasH = 128
            guard let canvas = CGContext(
                data: nil, width: canvasW, height: canvasH,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            for i in 0..<frameCount {
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
                let imgW = cgImage.width
                let imgH = cgImage.height
                let scale = min(Double(canvasW) / Double(imgW), Double(canvasH) / Double(imgH))
                let dw = Double(imgW) * scale
                let dh = Double(imgH) * scale
                let dx = (Double(canvasW) - dw) / 2
                let dy = (Double(canvasH) - dh) / 2

                // Clear canvas each frame for clean rendering
                canvas.clear(CGRect(x: 0, y: 0, width: canvasW, height: canvasH))
                canvas.draw(cgImage, in: CGRect(x: dx, y: dy, width: dw, height: dh))

                guard let snapshot = canvas.makeImage() else { continue }
                frames.append(NSImage(cgImage: snapshot, size: NSSize(width: CGFloat(canvasW), height: CGFloat(canvasH))))
            }
            guard !frames.isEmpty else { continue }
            avatarFrames[session.id] = frames
            avatarFrameIndices[session.id] = 0
        }
    }

    // MARK: - Animation

    private func startGifAnimation() {
        gifTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self else { return }
            var changed = false
            for (id, frames) in self.avatarFrames where frames.count > 1 {
                self.avatarFrameIndices[id] = ((self.avatarFrameIndices[id] ?? 0) + 1) % frames.count
                changed = true
            }
            if changed { self.needsDisplay = true }
        }
    }

    private func startIdleAnimation() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.eyeOffset = [-2, -1, 0, 1, 2].randomElement() ?? 0
            self.needsDisplay = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.eyeOffset = 0
                self.needsDisplay = true
            }
        }
    }

    private func doBounce() {
        isBouncing = true
        bounceOffset = 5
        needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.isBouncing = false
            self?.bounceOffset = 0
            self?.needsDisplay = true
        }
    }

    // MARK: - Mouse (click = bubble/terminal, drag = move window)

    private var mouseDownLocation: NSPoint?
    private var isDragging = false

    override func mouseDown(with event: NSEvent) {
        // Ctrl+click = right click
        if event.modifierFlags.contains(.control) {
            onRightClick?(event)
            return
        }
        mouseDownLocation = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = mouseDownLocation else { return }
        let current = event.locationInWindow
        let dx = current.x - origin.x
        let dy = current.y - origin.y

        if dx * dx + dy * dy > 9 {
            isDragging = true
            var frame = window!.frame
            frame.origin.x += dx
            frame.origin.y += dy
            window?.setFrameOrigin(frame.origin)
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownLocation = nil
            isDragging = false
        }
        guard !isDragging else { return }

        let point = convert(event.locationInWindow, from: nil)

        // 1) Bubble click → activate terminal + dismiss
        if let bubble = bubbleView, bubble.frame.contains(point) {
            onBubbleClicked?(activeSessionPath)
            hideBubble()
            return
        }

        // 2) Character click → activate terminal
        for (index, session) in sessions.enumerated() {
            let cx = slotCenterX(for: index)
            let cy = characterBaseY + characterSize / 2
            let dx = point.x - cx
            let dy = point.y - cy
            if sqrt(dx * dx + dy * dy) <= characterSize / 2 + 10 {
                TerminalManager.activate(forPath: session.cwdPattern)
                hideBubble()
                return
            }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }
}
