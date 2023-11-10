import Foundation
import SwiftUI
import Cocoa


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
        guard rightClickIndex != NSNotFound, let articles = planet.articles else { return nil }
        
        let menu = NSMenu()
        menu.addItem(withTitle: "Right Select \(rightClickIndex), Planet: \(planet.name), Article Count: \(articles.count)", action: nil, keyEquivalent: "")
        
        menu.addItem(deletionItem())
        
        return menu
    }
    
    // MARK: - Delete Article Item -

    private func deletionItem() -> NSMenuItem {
        let deletionItem = NSMenuItem()
        deletionItem.representedObject = planet.articles[rightClickIndex]
        deletionItem.title = "Delete Article"
        deletionItem.target = self
        deletionItem.action = #selector(self.deleteAction(_:))
        return deletionItem
    }
    
    @objc private func deleteAction(_ sender: Any?) {
        guard let object = sender as? NSMenuItem, let article = object.representedObject as? MyArticleModel else { return }
        
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Are you sure you want to delete this post?\n\n\(article.title)?\n\nThis action cannot be undone."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        alert.buttons.last?.hasDestructiveAction = true
        let result = alert.runModal()
        if result == .alertFirstButtonReturn {
            debugPrint("cancel")
        }
        if result == .alertSecondButtonReturn {
            debugPrint("deleting article: \(article.title), result: \(result)")
            article.delete()
        }
    }
}


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
