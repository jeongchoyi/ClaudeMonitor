//
//  BubbleView.swift
//  ClaudeMonitor
//
//  Created by Choyi on 2026/04/02.
//

import AppKit

class BubbleView: NSView {

    var onClick: (() -> Void)?

    private let message: String
    private let padding: CGFloat = 12
    private let tailHeight: CGFloat = 8
    private let maxTextWidth: CGFloat = 200

    private let textStorage: NSAttributedString

    init(message: String) {
        self.message = message

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping

        self.textStorage = NSAttributedString(
            string: message,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
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

        // Tail triangle
        let tailPath = NSBezierPath()
        let tailCenter = bounds.midX
        tailPath.move(to: NSPoint(x: tailCenter - 6, y: tailHeight))
        tailPath.line(to: NSPoint(x: tailCenter, y: 0))
        tailPath.line(to: NSPoint(x: tailCenter + 6, y: tailHeight))
        tailPath.close()

        // Shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 6
        shadow.set()

        NSColor.white.setFill()
        bubblePath.fill()
        tailPath.fill()

        // Reset shadow
        NSShadow().set()

        // Border
        NSColor(red: 0.486, green: 0.361, blue: 0.988, alpha: 0.3).setStroke()
        bubblePath.lineWidth = 1
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
