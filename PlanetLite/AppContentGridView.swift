import Foundation
import SwiftUI
import Cocoa
import ASMediaView


private class AppCollectionView: NSCollectionView {

    var planet: MyPlanetModel
    private var rightClickIndex: Int = NSNotFound

    init(planet: MyPlanetModel) {
        self.planet = planet
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        rightClickIndex = NSNotFound
        let point = convert(event.locationInWindow, from: nil)
        for index in 0..<numberOfItems(inSection: 0) {
            let frame = frameForItem(at: index)
            if NSMouseInRect(point, frame, isFlipped) {
                rightClickIndex = index
                break
            }
        }
        guard rightClickIndex != NSNotFound, let articles = planet.articles, rightClickIndex < articles.count else { return nil }

        let menu = NSMenu()

        menu.addItem(editPostItem())
        menu.addItem(settingsItem())

        menu.addItem(.separator())

        let items = IPFSItems()
        if items.count > 0 {
            for item in items {
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        menu.addItem(copyShareableItem())
        menu.addItem(openShareableItem())
        menu.addItem(testPostItem())

        menu.addItem(.separator())

        menu.addItem(shareItem())

        menu.addItem(.separator())

        menu.addItem(deletionItem())

        return menu
    }

    // MARK: - Settings Item

    private func settingsItem() -> NSMenuItem {
        let settingsItem = NSMenuItem()
        settingsItem.representedObject = planet.articles?[rightClickIndex] ?? nil
        settingsItem.title = "Settings"
        settingsItem.target = self
        settingsItem.action = #selector(settingsAction(_:))
        return settingsItem
    }

    @objc private func settingsAction(_ sender: Any?) {
        guard let object = sender as? NSMenuItem, let article = object.representedObject as? MyArticleModel else { return }
        PlanetStore.shared.selectedArticle = article
        PlanetStore.shared.isShowingMyArticleSettings = true
    }

    // MARK: - Edit Post Item

    private func editPostItem() -> NSMenuItem {
        let editItem = NSMenuItem()
        editItem.representedObject = planet.articles?[rightClickIndex] ?? nil
        editItem.title = "Edit Post"
        editItem.target = self
        editItem.action = #selector(editAction(_:))
        return editItem
    }

    @objc private func editAction(_ sender: Any?) {
        guard let object = sender as? NSMenuItem, let article = object.representedObject as? MyArticleModel else { return }
        try? WriterStore.shared.editArticle(for: article)
    }

    // MARK: - View on IPFS Items

    private func IPFSItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        if let article = planet.articles?[rightClickIndex], let attachments = article.attachments, attachments.count > 0 {
            for attachment in attachments {
                if let cids = article.cids, let cid = cids[attachment] {
                    let url = URL(string: "\(IPFSDaemon.shared.gateway)/ipfs/\(cid)")!
                    let item = NSMenuItem()
                    item.representedObject = url
                    item.title = "View \(attachment) on IPFS"
                    item.target = self
                    item.action = #selector(viewOnIPFSAction(_:))
                    items.append(item)
                }
            }
        }
        return items
    }

    @objc private func viewOnIPFSAction(_ sender: Any?) {
        guard let object = sender as? NSMenuItem, let url = object.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Copy Shareable Link

    private func copyShareableItem() -> NSMenuItem {
        let shareItem = NSMenuItem()
        shareItem.representedObject = planet.articles?[rightClickIndex] ?? nil
        shareItem.title = "Copy Shareable Link"
        shareItem.target = self
        shareItem.action = #selector(copyShareableAction(_:))
        return shareItem
    }

    @objc private func copyShareableAction(_ sender: Any?) {
        guard let object = sender as? NSMenuItem, let article = object.representedObject as? MyArticleModel, let url = article.browserURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    // MARK: - Open Shareable Link in Browser

    private func openShareableItem() -> NSMenuItem {
        let shareItem = NSMenuItem()
        shareItem.representedObject = planet.articles?[rightClickIndex] ?? nil
        shareItem.title = "Open Shareable Link in Browser"
        shareItem.target = self
        shareItem.action = #selector(openShareableAction(_:))
        return shareItem
    }

    @objc private func openShareableAction(_ sender: Any?) {
        guard let object = sender as? NSMenuItem, let article = object.representedObject as? MyArticleModel, let url = article.browserURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Test Post in Browser Item

    private func testPostItem() -> NSMenuItem {
        let testItem = NSMenuItem()
        testItem.representedObject = planet.articles?[rightClickIndex] ?? nil
        testItem.title = "Test Post in Browser"
        testItem.target = self
        testItem.action = #selector(testAction(_:))
        return testItem
    }

    @objc private func testAction(_ sender: Any?) {
        guard let object = sender as? NSMenuItem, let article = object.representedObject as? MyArticleModel, let url = article.localGatewayURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Share Article Item

    private func shareItem() -> NSMenuItem {
        let shareItem = NSMenuItem()
        shareItem.representedObject = planet.articles?[rightClickIndex] ?? nil
        shareItem.title = "Share"
        shareItem.target = self
        shareItem.action = #selector(shareAction(_:))
        return shareItem
    }

    @objc private func shareAction(_ sender: Any?) {
        guard let object = sender as? NSMenuItem, let article = object.representedObject as? MyArticleModel, let itemView = self.item(at: rightClickIndex), let url = article.browserURL else { return }
        let sharingPicker = NSSharingServicePicker(items: [url])
        sharingPicker.delegate = self
        sharingPicker.show(relativeTo: .zero, of: itemView.view, preferredEdge: .minY)
    }

    // MARK: - Delete Post Item

    private func deletionItem() -> NSMenuItem {
        let deletionItem = NSMenuItem()
        deletionItem.representedObject = planet.articles?[rightClickIndex] ?? nil
        deletionItem.title = "Delete Post"
        deletionItem.target = self
        deletionItem.action = #selector(deleteAction(_:))
        return deletionItem
    }

    @objc private func deleteAction(_ sender: Any?) {
        guard let object = sender as? NSMenuItem, let article = object.representedObject as? MyArticleModel else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Are you sure you want to delete this post?\n\n\(article.title)\n\nThis action cannot be undone."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        alert.buttons.last?.hasDestructiveAction = true
        let result = alert.runModal()
        if result == .alertSecondButtonReturn {
            ASMediaManager.shared.deactivateView(byID: article.id)
            article.delete()
            planet.updated = Date()
            try? planet.save()
            Task {
                try? await planet.savePublic()
                try? await planet.publish()
            }
        }
    }
}


extension AppCollectionView: NSSharingServicePickerDelegate {
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        guard let image = NSImage(systemSymbolName: "link", accessibilityDescription: "Link") else {
            return proposedServices
        }
        var share = proposedServices
        let copyService = NSSharingService(title: "Copy Link", image: image, alternateImage: image) {
            if let item = items.first as? URL {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.absoluteString, forType: .string)
            }
        }
        share.insert(copyService, at: 0)
        return share
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        sharingServicePicker.delegate = nil
    }
}


// MARK: -

struct AppContentGridView: NSViewRepresentable {
    @ObservedObject var planet: MyPlanetModel
    var itemSize: NSSize

    // MARK: - Coordinator for Delegate & Data Source & Flow Layout

    class Coordinator: NSObject, NSCollectionViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
        var parent: AppContentGridView
        var articles: [MyArticleModel]
        var itemSize: NSSize

        init(parent: AppContentGridView, articles: [MyArticleModel], itemSize: NSSize) {
            self.parent = parent
            self.articles = articles
            self.itemSize = itemSize
        }

        func numberOfSections(in collectionView: NSCollectionView) -> Int {
            return 1
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            return articles.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let item = collectionView.makeItem(withIdentifier: .init(AppContentGridCell.identifier), for: indexPath) as! AppContentGridCell
            let article = articles[indexPath.item]
            item.configureCell(article, size: itemSize)
            return item
        }

        func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
            return parent.itemSize
        }

        func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
            return 16
        }

        func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
            return 16
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self, articles: planet.articles, itemSize: itemSize)
    }

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> some NSScrollView {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.sectionInset = .init(top: 16, left: 16, bottom: 16, right: 16)
        let collectionView = AppCollectionView(planet: planet)
        collectionView.delegate = context.coordinator
        collectionView.dataSource = context.coordinator
        collectionView.collectionViewLayout = layout
        collectionView.allowsEmptySelection = false
        collectionView.allowsMultipleSelection = false
        collectionView.isSelectable = false
        let scrollView = NSScrollView()
        scrollView.documentView = collectionView
        collectionView.register(AppContentGridCell.self, forItemWithIdentifier: .init(AppContentGridCell.identifier))
        return scrollView
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        if let collectionView = nsView.documentView as? AppCollectionView {
            collectionView.planet = planet
            context.coordinator.articles = planet.articles
            context.coordinator.itemSize = itemSize
            collectionView.reloadData()
        }
    }
}
