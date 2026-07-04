import AppKit

protocol ClipItemCellDelegate: AnyObject {
    func clipItemCell(_ cell: NSCollectionViewItem, didRightClick event: NSEvent)
}

final class ClipCollectionViewItem: NSCollectionViewItem {
    weak var cellDelegate: ClipItemCellDelegate?
    private let container = NSView()
    private let tagView = NSView()
    private let tagImageView = NSImageView()
    private let tagLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let indexLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private var hoverTracking: NSTrackingArea?
    private var isHovering = false

    override func loadView() {
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 1
        container.layer?.borderColor = Theme.border.cgColor
        container.layer?.backgroundColor = .clear

        tagView.wantsLayer = true
        tagView.layer?.cornerRadius = 7
        tagView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tagView)

        tagImageView.translatesAutoresizingMaskIntoConstraints = false
        tagImageView.imageScaling = .scaleProportionallyUpOrDown
        tagImageView.isHidden = true
        tagView.addSubview(tagImageView)

        tagLabel.font = .systemFont(ofSize: 15)
        tagLabel.alignment = .center
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        tagView.addSubview(tagLabel)

        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = Theme.text
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.cell?.truncatesLastVisibleLine = true
        titleLabel.cell?.backgroundStyle = .dark
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = Theme.textFaint
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.cell?.truncatesLastVisibleLine = true
        subtitleLabel.isBezeled = false
        subtitleLabel.drawsBackground = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)

        indexLabel.font = .systemFont(ofSize: 10, weight: .medium)
        indexLabel.textColor = Theme.textFaint
        indexLabel.alignment = .center
        indexLabel.isBezeled = false
        indexLabel.drawsBackground = false
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(indexLabel)

        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textColor = Theme.textFaint
        timeLabel.alignment = .right
        timeLabel.isBezeled = false
        timeLabel.drawsBackground = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            tagView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            tagView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            tagView.widthAnchor.constraint(equalToConstant: 36),
            tagView.heightAnchor.constraint(equalToConstant: 36),

            tagImageView.topAnchor.constraint(equalTo: tagView.topAnchor, constant: 3),
            tagImageView.bottomAnchor.constraint(equalTo: tagView.bottomAnchor, constant: -3),
            tagImageView.leadingAnchor.constraint(equalTo: tagView.leadingAnchor, constant: 3),
            tagImageView.trailingAnchor.constraint(equalTo: tagView.trailingAnchor, constant: -3),

            tagLabel.centerXAnchor.constraint(equalTo: tagView.centerXAnchor),
            tagLabel.centerYAnchor.constraint(equalTo: tagView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: tagView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: indexLabel.leadingAnchor, constant: -10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -10),

            indexLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            indexLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            indexLabel.widthAnchor.constraint(equalToConstant: 14),

            timeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            timeLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            timeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80),
        ])

        view = container
    }

    func configure(with item: ClipItem, index: Int) {
        let tagColor = Theme.tagColor(item.category)
        tagView.layer?.backgroundColor = tagColor.withAlphaComponent(0.15).cgColor

        if item.category == .image, let path = item.payloadURL, let img = NSImage(contentsOfFile: path) {
            tagImageView.image = img
            tagImageView.isHidden = false
            tagLabel.isHidden = true
        } else {
            tagImageView.isHidden = true
            tagLabel.isHidden = false
            tagLabel.stringValue = item.category.emoji
            tagLabel.textColor = tagColor
        }

        titleLabel.stringValue = item.displayTitle
        subtitleLabel.stringValue = item.subtitle
        indexLabel.stringValue = "\(index)"
        timeLabel.stringValue = item.relativeTime()

        updateAppearance()
    }

    private func updateAppearance() {
        if isSelected {
            container.layer?.backgroundColor = NSColor(srgbRed: 0.37, green: 0.62, blue: 1.0, alpha: 0.12).cgColor
            container.layer?.borderColor = NSColor(srgbRed: 0.37, green: 0.62, blue: 1.0, alpha: 0.3).cgColor
        } else if isHovering {
            container.layer?.backgroundColor = NSColor(white: 1, alpha: 0.04).cgColor
            container.layer?.borderColor = Theme.border.cgColor
        } else {
            container.layer?.backgroundColor = .clear
            container.layer?.borderColor = Theme.border.cgColor
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
