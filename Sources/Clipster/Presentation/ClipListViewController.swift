import AppKit

struct ClipGroupSidebarItem: Equatable {
    let id: Int64
    let name: String
    let color: NSColor
}

protocol ClipListDelegate: AnyObject {
    func didClickItem(_ item: ClipItem)
    func didHighlightItem(_ item: ClipItem)
    func didToggleFavorite(_ item: ClipItem)
    func didDeleteItem(_ item: ClipItem)
}

final class ClipListViewController: NSViewController, CategoryButtonDelegate {
    weak var delegate: ClipListDelegate?

    private let repository: ItemRepository
    private let searchService: SearchService
    private let groupRepository: GroupRepository

    private var items: [ClipItem] = []
    private var currentCategory: Category?
    private var currentGroupId: Int64?
    private var keyword = ""

    private var sidebarStack: NSStackView!
    private var collectionView: NSCollectionView!
    private var listLayout: NSCollectionViewFlowLayout!
    private var gridLayout: NSCollectionViewFlowLayout!
    private var scrollView: NSScrollView!
    var searchField: NSSearchField!
    private var statusLabel: NSTextField!
    private var titleLabel: NSTextField!
    private var categoryButtons: [(Category?, CategoryButton)] = []
    private var groupButtons: [(Int64, CategoryButton)] = []
    private var groups: [ClipGroup] = []
    private var currentRightClickedItemId: Int64?

    private var groupsSectionHeader: NSView?

    init(_ repository: ItemRepository, _ searchService: SearchService, _ groupRepository: GroupRepository) {
        self.repository = repository
        self.searchService = searchService
        self.groupRepository = groupRepository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = Theme.bg.cgColor
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        reloadData()
    }

    // MARK: - Layout

    private func setupLayout() {
        let sidebar = buildSidebar()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebar)

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = Theme.border.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)

        let content = buildContent()
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        NSLayoutConstraint.activate([
            sidebar.topAnchor.constraint(equalTo: view.topAnchor),
            sidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 200),

            separator.topAnchor.constraint(equalTo: view.topAnchor),
            separator.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),

            content.topAnchor.constraint(equalTo: view.topAnchor),
            content.leadingAnchor.constraint(equalTo: separator.trailingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Sidebar

    private func buildSidebar() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(srgbRed: 0.05, green: 0.05, blue: 0.06, alpha: 1).cgColor

        searchField = NSSearchField()
        searchField.placeholderString = "搜索全部内容..."
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 13)
        searchField.wantsLayer = true
        searchField.layer?.cornerRadius = 8
        searchField.layer?.backgroundColor = Theme.surface3.cgColor
        container.addSubview(searchField)

        sidebarStack = NSStackView()
        sidebarStack.orientation = .vertical
        sidebarStack.spacing = 2
        sidebarStack.distribution = .fill
        sidebarStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sidebarStack)

        let allBtn = makeCategoryButton(emoji: "⌘", title: "全部", category: nil)
        allBtn.isSelected = true
        categoryButtons.append((nil, allBtn))
        sidebarStack.addArrangedSubview(allBtn)

        addSidebarLabel("分类")
        for cat in [Category.text, .link, .image, .code] {
            let btn = makeCategoryButton(emoji: cat.emoji, title: cat.displayName, category: cat)
            categoryButtons.append((cat, btn))
            sidebarStack.addArrangedSubview(btn)
        }

        reloadGroups(into: sidebarStack)

        reloadGroups(into: sidebarStack)

        addSidebarLabel("收藏")
        let favBtn = makeCategoryButton(emoji: "⭐", title: "常用", category: .favorite)
        categoryButtons.append((.favorite, favBtn))
        sidebarStack.addArrangedSubview(favBtn)
        let lockBtn = makeCategoryButton(emoji: "🔒", title: "私密", category: Category.locked)
        categoryButtons.append((Category.locked, lockBtn))
        sidebarStack.addArrangedSubview(lockBtn)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            sidebarStack.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            sidebarStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            sidebarStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            sidebarStack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -10),
        ])

        return container
    }

    func reloadGroups(into stack: NSStackView? = nil) {
        guard let target = stack ?? sidebarStack else { return }

        for (_, btn) in groupButtons { btn.removeFromSuperview() }
        groupButtons.removeAll()
        groupsSectionHeader?.removeFromSuperview()
        groupsSectionHeader = nil

        groups = groupRepository.fetchAll()

        let favIndex = target.arrangedSubviews.firstIndex { view in
            (view as? NSTextField)?.stringValue == "收藏"
        } ?? target.arrangedSubviews.count

        let header = makeSidebarSectionHeader("我的分组", action: #selector(createGroup))
        groupsSectionHeader = header
        target.insertArrangedSubview(header, at: favIndex)

        for (offset, group) in groups.enumerated() {
            let btn = makeGroupButton(group)
            groupButtons.append((group.id!, btn))
            target.insertArrangedSubview(btn, at: favIndex + offset + 1)
        }
        updateGroupCounts()
    }

    private func makeSidebarSectionHeader(_ text: String, action: Selector) -> NSView {
        let container = NSView()
        container.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = Theme.textFaint
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let button = NSButton(title: "+ 新建", target: self, action: action)
        button.bezelStyle = .inline
        button.font = .systemFont(ofSize: 11)
        button.contentTintColor = Theme.accent
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    func categoryButtonDidClick(_ button: CategoryButton) {
        if let cat = button.category {
            for (_, btn) in categoryButtons { btn.isSelected = false }
            for (_, btn) in groupButtons { btn.isSelected = false }
            button.isSelected = true
            currentCategory = cat
            currentGroupId = nil
            reloadData()
        } else if let gid = button.groupId {
            for (_, btn) in categoryButtons { btn.isSelected = false }
            for (_, btn) in groupButtons { btn.isSelected = false }
            button.isSelected = true
            currentCategory = nil
            currentGroupId = gid
            reloadData()
        }
    }

    @objc private func createGroup() {
        showGroupEditor()
    }

    private func makeGroupButton(_ group: ClipGroup) -> CategoryButton {
        let btn = CategoryButton()
        btn.titleText = group.name
        btn.countText = "0"
        btn.groupId = group.id
        btn.colorDot = group.nsColor
        btn.delegate = self
        btn.menuProvider = self
        btn.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return btn
    }

    private func updateGroupCounts() {
        for (gid, btn) in groupButtons {
            btn.countText = "\(groupRepository.itemCount(in: gid))"
        }
    }

    private func addSidebarLabel(_ text: String) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = Theme.textFaint
        label.heightAnchor.constraint(equalToConstant: 26).isActive = true
        sidebarStack.addArrangedSubview(label)
        sidebarStack.setCustomSpacing(2, after: label)
    }

    private func makeCategoryButton(emoji: String, title: String, category: Category?) -> CategoryButton {
        let btn = CategoryButton()
        btn.emoji = emoji
        btn.titleText = title
        btn.countText = "0"
        btn.category = category
        btn.delegate = self
        btn.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return btn
    }

    @objc private func categorySelected(_ sender: CategoryButton) {
        categoryButtonDidClick(sender)
    }

    @objc private func searchChanged() {
        keyword = searchField.stringValue
        reloadData()
    }

    // MARK: - Content

    private func buildContent() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = Theme.bg.cgColor

        let header = NSView()
        header.wantsLayer = true
        header.layer?.backgroundColor = NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1).cgColor
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        titleLabel = NSTextField(labelWithString: "Clipster")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = Theme.text
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        let flow = NSCollectionViewFlowLayout()
        flow.minimumLineSpacing = 4
        flow.sectionInset = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        flow.itemSize = NSSize(width: 520, height: 56)
        self.listLayout = flow

        let grid = NSCollectionViewFlowLayout()
        grid.minimumLineSpacing = 12
        grid.minimumInteritemSpacing = 12
        grid.sectionInset = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        grid.itemSize = NSSize(width: 140, height: 140)
        self.gridLayout = grid

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = flow
        collectionView.backgroundColors = [.clear]
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.register(ClipCollectionViewItem.self, forItemWithIdentifier: .clipItem)
        collectionView.register(ImageCollectionViewItem.self, forItemWithIdentifier: .imageItem)

        scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.wantsLayer = true
        container.addSubview(scrollView)

        let statusView = NSView()
        statusView.wantsLayer = true
        statusView.layer?.backgroundColor = NSColor(srgbRed: 0.06, green: 0.06, blue: 0.07, alpha: 1).cgColor
        statusView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(statusView)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = Theme.textFaint
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusView.addSubview(statusLabel)

        let monitorLabel = NSTextField(labelWithString: "⏻ 监听中")
        monitorLabel.font = .systemFont(ofSize: 11)
        monitorLabel.textColor = Theme.green
        monitorLabel.translatesAutoresizingMaskIntoConstraints = false
        statusView.addSubview(monitorLabel)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusView.topAnchor),

            statusView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            statusView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            statusView.heightAnchor.constraint(equalToConstant: 28),

            statusLabel.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 16),
            statusLabel.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),

            monitorLabel.trailingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: -16),
            monitorLabel.centerYAnchor.constraint(equalTo: statusView.centerYAnchor),
        ])

        return container
    }

    // MARK: - Data

    func reloadData() {
        items = searchService.search(keyword: keyword, category: currentCategory, groupId: currentGroupId)

        let isImageMode = currentCategory == .image || (currentGroupId != nil && items.allSatisfy { $0.category == .image })
        if isImageMode && !items.isEmpty {
            collectionView.collectionViewLayout = gridLayout
        } else {
            collectionView.collectionViewLayout = listLayout
        }

        collectionView.reloadData()
        let total = repository.count()
        titleLabel.stringValue = "Clipster — \(total) 条记录"
        statusLabel.stringValue = "⌃⌘M 唤出    ⌃K 搜索    数字键直达"
        updateCategoryCounts()
        updateGroupCounts()
    }

    private func updateCategoryCounts() {
        let counts = repository.countByCategory()
        let total = repository.count()
        for (cat, btn) in categoryButtons {
            if cat == nil {
                btn.countText = "\(total)"
            } else if let c = cat {
                btn.countText = "\(counts[c] ?? 0)"
            }
        }
    }

    func selectIndex(_ index: Int) {
        guard index < items.count, index >= 0 else { return }
        collectionView.selectionIndexPaths = [IndexPath(item: index, section: 0)]
        if let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
            let indexPath = IndexPath(item: index, section: 0)
            if let attr = layout.layoutAttributesForItem(at: indexPath) {
                collectionView.scrollToVisible(attr.frame)
            }
        }
        delegate?.didHighlightItem(items[index])
    }

    func moveSelection(_ delta: Int) {
        let current = collectionView.selectionIndexPaths.first?.item ?? -1
        let next = current + delta
        guard next >= 0, next < items.count else { return }
        selectIndex(next)
    }

    func selectCategoryIndex(_ index: Int) {
        guard index >= 0, index < categoryButtons.count else { return }
        let btn = categoryButtons[index].1
        for (_, b) in categoryButtons { b.isSelected = false }
        btn.isSelected = true
        currentCategory = btn.category
        reloadData()
    }

    func focusSearchField() {
        view.window?.makeFirstResponder(searchField)
    }

    // MARK: - Groups

    func showGroupEditor(group: ClipGroup? = nil) {
        let alert = NSAlert()
        alert.messageText = group == nil ? "新建分组" : "编辑分组"
        alert.informativeText = "输入分组名称："
        alert.alertStyle = .informational
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.stringValue = group?.name ?? ""
        input.placeholderString = "例如：工作素材"
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if groupRepository.exists(name: name) && group?.name != name {
            let warning = NSAlert()
            warning.messageText = "分组已存在"
            warning.informativeText = "名称为「\(name)」的分组已经存在。"
            warning.alertStyle = .warning
            warning.runModal()
            return
        }

        if var existing = group {
            existing.name = name
            existing.updatedAt = Date()
            _ = groupRepository.update(existing)
        } else {
            let newGroup = ClipGroup(name: name)
            _ = groupRepository.insert(newGroup)
        }
        reloadGroups()
        reloadData()
    }

    func showAddToGroupSheet(for item: ClipItem) {
        let menu = buildGroupSubmenu(for: item)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func toggleGroup(_ sender: NSMenuItem) {
        guard let ctx = sender.representedObject as? GroupActionContext else { return }
        if sender.state == .on {
            groupRepository.removeItem(ctx.itemId, from: ctx.groupId)
            sender.state = .off
        } else {
            _ = groupRepository.addItem(ctx.itemId, to: ctx.groupId)
            sender.state = .on
        }
        reloadData()
    }

    @objc private func createGroupFromMenu(_ sender: NSMenuItem) {
        showGroupEditor()
    }

    private func circleImage(color: NSColor, size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        let path = NSBezierPath(ovalIn: NSRect(origin: .zero, size: size))
        path.fill()
        image.unlockFocus()
        return image
    }
}

extension ClipListViewController: CategoryButtonMenuProvider {
    func menuForCategoryButton(_ button: CategoryButton) -> NSMenu? {
        guard let gid = button.groupId, let group = groups.first(where: { $0.id == gid }) else { return nil }
        let menu = NSMenu()
        menu.appearance = NSAppearance(named: .darkAqua)
        menu.font = .systemFont(ofSize: 13)

        let editItem = NSMenuItem(title: "编辑分组", action: #selector(editGroup(_:)), keyEquivalent: "")
        editItem.target = self
        editItem.representedObject = group
        menu.addItem(editItem)

        let deleteItem = NSMenuItem(title: "删除分组", action: #selector(deleteGroup(_:)), keyEquivalent: "")
        deleteItem.target = self
        deleteItem.representedObject = group
        menu.addItem(deleteItem)

        return menu
    }

    @objc private func editGroup(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? ClipGroup else { return }
        showGroupEditor(group: group)
    }

    @objc private func deleteGroup(_ sender: NSMenuItem) {
        guard let group = sender.representedObject as? ClipGroup, let id = group.id else { return }
        let alert = NSAlert()
        alert.messageText = "删除分组"
        alert.informativeText = "确定删除「\(group.name)」吗？分组内的条目会保留在全部列表中。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        groupRepository.delete(id: id)
        if currentGroupId == id {
            currentGroupId = nil
            currentCategory = nil
            for (_, btn) in categoryButtons { btn.isSelected = false }
            categoryButtons.first?.1.isSelected = true
        }
        reloadGroups()
        reloadData()
    }
}

// MARK: - CollectionView

extension ClipListViewController: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        if currentCategory == .image {
            let item = collectionView.makeItem(withIdentifier: .imageItem, for: indexPath) as! ImageCollectionViewItem
            item.configure(with: items[indexPath.item], index: indexPath.item + 1)
            item.cellDelegate = self
            return item
        } else {
            let item = collectionView.makeItem(withIdentifier: .clipItem, for: indexPath) as! ClipCollectionViewItem
            item.configure(with: items[indexPath.item], index: indexPath.item + 1)
            item.cellDelegate = self
            return item
        }
    }
}

extension ClipListViewController: NSCollectionViewDelegate, ClipItemCellDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let idx = indexPaths.first else { return }
        delegate?.didClickItem(items[idx.item])
    }

    func clipItemCell(_ cell: NSCollectionViewItem, didRightClick event: NSEvent) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        let item = items[indexPath.item]
        delegate?.didHighlightItem(item)

        let menu = NSMenu()
        menu.appearance = NSAppearance(named: .darkAqua)
        menu.font = .systemFont(ofSize: 13)
        menu.showsStateColumn = true

        let addItem = NSMenuItem(title: "加入分组", action: nil, keyEquivalent: "")
        addItem.submenu = buildGroupSubmenu(for: item)
        menu.addItem(addItem)

        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func buildGroupSubmenu(for item: ClipItem) -> NSMenu {
        guard let itemId = item.id else { return NSMenu() }
        currentRightClickedItemId = itemId
        let groups = groupRepository.fetchAll()
        let selectedIds = Set(groupRepository.groupIds(for: itemId))

        let menu = NSMenu()
        menu.appearance = NSAppearance(named: .darkAqua)
        menu.font = .systemFont(ofSize: 13)
        menu.showsStateColumn = true

        for group in groups {
            guard let gid = group.id else { continue }
            let menuItem = NSMenuItem(title: group.name, action: #selector(toggleGroup(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = GroupActionContext(itemId: itemId, groupId: gid)
            menuItem.state = selectedIds.contains(gid) ? .on : .off
            menuItem.image = circleImage(color: group.nsColor, size: NSSize(width: 10, height: 10))
            menu.addItem(menuItem)
        }

        if !groups.isEmpty {
            menu.addItem(.separator())
        }

        let createItem = NSMenuItem(title: "+ 新建分组", action: #selector(createGroupFromMenu(_:)), keyEquivalent: "")
        createItem.target = self
        menu.addItem(createItem)

        return menu
    }
}

extension NSUserInterfaceItemIdentifier {
    static let clipItem = NSUserInterfaceItemIdentifier("ClipItem")
}

