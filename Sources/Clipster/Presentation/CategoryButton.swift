import AppKit

protocol CategoryButtonDelegate: AnyObject {
    func categoryButtonDidClick(_ button: CategoryButton)
}

protocol CategoryButtonMenuProvider: AnyObject {
    func menuForCategoryButton(_ button: CategoryButton) -> NSMenu?
}

final class CategoryButton: NSView {
    var category: Category?
    var groupId: Int64?
    weak var menuProvider: CategoryButtonMenuProvider?
    var emoji: String = "" {
        didSet { needsDisplay = true }
    }
    var colorDot: NSColor? {
        didSet { needsDisplay = true }
    }
    var titleText: String = "" {
        didSet { needsDisplay = true }
    }
    var countText: String = "" {
        didSet { needsDisplay = true }
    }
    var isSelected = false {
        didSet { needsDisplay = true }
    }
    weak var delegate: CategoryButtonDelegate?

    private var isHovering = false
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 8
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea { removeTrackingArea(area) }
        let new = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        trackingArea = new
        addTrackingArea(new)
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.categoryButtonDidClick(self)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = menuProvider?.menuForCategoryButton(self) {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bgColor: NSColor
        if isSelected {
            bgColor = NSColor(srgbRed: 0.37, green: 0.62, blue: 1.0, alpha: 0.18)
        } else if isHovering {
            bgColor = NSColor(white: 1, alpha: 0.05)
        } else {
            bgColor = .clear
        }
        bgColor.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8).fill()

        let accentColor: NSColor = isSelected ? Theme.accent : Theme.textDim
        let emojiAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: accentColor]
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: isSelected ? .medium : .regular),
            .foregroundColor: accentColor,
        ]
        let countAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: Theme.textFaint]

        let padding: CGFloat = 10
        let iconSize = CGSize(width: 16, height: 16)

        if let dot = colorDot {
            let dotRect = NSRect(x: padding + 3, y: (bounds.height - iconSize.height) / 2, width: iconSize.width - 6, height: iconSize.height - 6)
            let path = NSBezierPath(ovalIn: dotRect)
            dot.setFill()
            path.fill()
        } else {
            let emojiSize = (emoji as NSString).size(withAttributes: emojiAttr)
            let centerY = (bounds.height - emojiSize.height) / 2
            (emoji as NSString).draw(at: NSPoint(x: padding, y: centerY), withAttributes: emojiAttr)
        }

        let titleSize = (titleText as NSString).size(withAttributes: titleAttr)
        let titleY = (bounds.height - titleSize.height) / 2
        (titleText as NSString).draw(at: NSPoint(x: padding + 22, y: titleY), withAttributes: titleAttr)

        let countSize = (countText as NSString).size(withAttributes: countAttr)
        if !countText.isEmpty {
            let countX = bounds.width - padding - countSize.width
            (countText as NSString).draw(at: NSPoint(x: countX, y: titleY + 1), withAttributes: countAttr)
        }
    }
}
