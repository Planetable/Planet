import Foundation
import SwiftUI
import Cocoa


struct AppContentGridView: NSViewRepresentable {
    @ObservedObject var planet: MyPlanetModel
    
    static let layoutNotification: Notification.Name = Notification.Name("AppContentGridViewWillLayoutNotification")
    
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
            let currentViewSize = collectionView.bounds.size
            let targetItemSize = NSSize(width: (currentViewSize.width - 16 * 3) / 2.0, height: itemSize.height)
            debugPrint("current view size: \(currentViewSize), item size: \(targetItemSize)")
            return targetItemSize
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
        let collectionView = NSCollectionView()
        collectionView.delegate = context.coordinator
        collectionView.dataSource = context.coordinator
        collectionView.collectionViewLayout = layout
        collectionView.allowsEmptySelection = false
        collectionView.allowsMultipleSelection = false
        collectionView.isSelectable = false
        let scrollView = NSScrollView()
        scrollView.documentView = collectionView
        collectionView.register(AppContentGridCell.self, forItemWithIdentifier: .init(AppContentGridCell.identifier))
        
        NotificationCenter.default.addObserver(forName: Self.layoutNotification, object: nil, queue: nil) { _ in
            DispatchQueue.main.async {
                collectionView.collectionViewLayout?.invalidateLayout()
            }
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSViewType, context: Context) {
        if let collectionView = nsView.documentView as? NSCollectionView {
            context.coordinator.articles = planet.articles
            context.coordinator.itemSize = itemSize
            collectionView.reloadData()
            debugPrint("reloading collection view ... view size: \(collectionView.bounds.size), item size: \(itemSize)")
        }
    }
}
