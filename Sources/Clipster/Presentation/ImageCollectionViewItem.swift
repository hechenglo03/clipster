import AppKit

final class ImageCollectionViewItem: NSCollectionViewItem {
    weak var cellDelegate: ClipItemCellDelegate?
    private let container = NSView()
    private let thumbImageView = NSImageView()
    private let indexLabel = NSTextField(labelWithString: "")
    private var hoverTracking: NSTrackingArea?
    private var isHovering = false

    override func loadView() {
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 1
        container.layer?.borderColor = Theme.border.cgColor
        container.layer?.backgroundColor = NSColor(white: 1, alpha: 0.03).cgColor

        thumbImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbImageView.imageScaling = .scaleProportionallyUpOrDown
        thumbImageView.wantsLayer = true
        thumbImageView.layer?.cornerRadius = 8
        container.addSubview(thumbImageView)

        indexLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        indexLabel.textColor = .white
        indexLabel.alignment = .center
        indexLabel.isBezeled = false
        indexLabel.drawsBackground = false
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.wantsLayer = true
        indexLabel.layer?.cornerRadius = 4
        indexLabel.layer?.backgroundColor = NSColor(white: 0, alpha: 0.5).cgColor
        container.addSubview(indexLabel)

        NSLayoutConstraint.activate([
            thumbImageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            thumbImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            thumbImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            thumbImageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),

            indexLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            indexLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            indexLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            indexLabel.heightAnchor.constraint(equalToConstant: 18),
        ])

        view = container
    }

    func configure(with item: ClipItem, index: Int) {
        if let path = item.payloadURL {
            thumbImageView.image = NSImage(contentsOfFile: path)
        } else {
            thumbImageView.image = nil
        }
        indexLabel.stringValue = "\(index)"
        updateAppearance()
    }

    private func updateAppearance() {
        if isSelected {
            container.layer?.borderColor = NSColor(srgbRed: 0.37, green: 0.62, blue: 1.0, alpha: 0.6).cgColor
            container.layer?.backgroundColor = NSColor(srgbRed: 0.37, green: 0.62, blue: 1.0, alpha: 0.12).cgColor
        } else if isHovering {
            container.layer?.borderColor = Theme.borderStrong.cgColor
            container.layer?.backgroundColor = NSColor(white: 1, alpha: 0.06).cgColor
        } else {
            container.layer?.borderColor = Theme.border.cgColor
            container.layer?.backgroundColor = NSColor(white: 1, alpha: 0.03).cgColor
        }
    }

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        view.addTrackingArea(area)
    }

    override func rightMouseDown(with event: NSEvent) {
        cellDelegate?.clipItemCell(self, didRightClick: event)
    }
}

extension NSUserInterfaceItemIdentifier {
    static let imageItem = NSUserInterfaceItemIdentifier("ImageItem")
}
