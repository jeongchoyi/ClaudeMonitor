//
//  BubbleView.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import AppKit

class BubbleView: NSView {

    var onClick: (() -> Void)?

    // X position of the tail tip in the bubble's coordinate space.
    // Set by the owner so the tail points at the character, even when the
    // bubble is clamped to the window edge.
    var tailX: CGFloat? {
        didSet { needsDisplay = true }
    }

    private let message: String
    private let borderColor: NSColor
    private let padding: CGFloat = 12
    private let tailHeight: CGFloat = 8
    private let tailHalfWidth: CGFloat = 6
    private let maxTextWidth: CGFloat = 200

    private let textStorage: NSAttributedString

    init(message: String, borderColor: NSColor) {
        self.message = message
        self.borderColor = borderColor

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping

        self.textStorage = NSAttributedString(
            string: message,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style,
            ]
        )

        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let textSize = textStorage.boundingRect(
            with: NSSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size

        return NSSize(
            width: ceil(textSize.width) + padding * 2 + 4,
            height: ceil(textSize.height) + padding * 2 + tailHeight
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bubbleRect = NSRect(
            x: 1,
            y: tailHeight,
            width: bounds.width - 2,
            height: bounds.height - tailHeight - 1
        )

        let bubblePath = NSBezierPath(roundedRect: bubbleRect, xRadius: 10, yRadius: 10)

        // Tail triangle — pointed at tailX if provided, clamped to stay on
        // the bubble edge with room for the triangle base.
        let minTail = tailHalfWidth + 10
        let maxTail = bounds.width - tailHalfWidth - 10
        let rawTail = tailX ?? bounds.midX
        let tailCenter = min(max(rawTail, minTail), maxTail)
        let tailPath = NSBezierPath()
        tailPath.move(to: NSPoint(x: tailCenter - tailHalfWidth, y: tailHeight))
        tailPath.line(to: NSPoint(x: tailCenter, y: 0))
        tailPath.line(to: NSPoint(x: tailCenter + tailHalfWidth, y: tailHeight))
        tailPath.close()

        // Shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 10
        shadow.set()

        NSColor.white.setFill()
        bubblePath.fill()
        tailPath.fill()

        // Reset shadow
        NSShadow().set()

        // Border — thicker and more saturated so the bubble stands out
        borderColor.setStroke()
        bubblePath.lineWidth = 2
        bubblePath.stroke()

        // Text
        let textRect = NSRect(
            x: padding,
            y: tailHeight + padding,
            width: bounds.width - padding * 2,
            height: bounds.height - tailHeight - padding * 2
        )
        textStorage.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    // MARK: - Click

    override func mouseDown(with event: NSEvent) {
        alphaValue = 0.7
    }

    override func mouseUp(with event: NSEvent) {
        alphaValue = 1.0
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            onClick?()
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
