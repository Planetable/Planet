import Foundation
import SwiftUI
import Cocoa


struct AppContentGridView: NSViewRepresentable {
    @ObservedObject var planet: MyPlanetModel
    
    static let layoutNotification: Notification.Name = Notification.Name("AppContentGridViewWillLayoutNotification")
    static let gridPadding: CGFloat = 16
    static let gridItemMinWidth: CGFloat = 128
    static let gridItemMaxWidth: CGFloat = 256

    // MARK: - Coordinator for Delegate & Data Source & Flow Layout

    class Coordinator: NSObject, NSCollectionViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
        var parent: AppContentGridView
        var articles: [MyArticleModel]

        init(parent: AppContentGridView, articles: [MyArticleModel]) {
            self.parent = parent
            self.articles = articles
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
            item.configureCell(article)
            return item
        }
        
        func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
            let currentViewSize = collectionView.bounds.size
            let maxItemWidth: CGFloat = AppContentGridView.gridItemMaxWidth
            let itemRatio: CGFloat = 4.0 / 3.0
            // full-screen width of a popular 13-inch Mac's built-in screen
            if currentViewSize.width > 1440 {
                return NSSize(width: maxItemWidth, height: maxItemWidth / itemRatio)
            } else if currentViewSize.width < 600 {
                let bestItemWidth = calculateItemWidth(containerWidth: currentViewSize.width, numberOfItems: 3)
                return NSSize(width: bestItemWidth, height: bestItemWidth / itemRatio)
            } else if currentViewSize.width < 800 {
                let bestItemWidth = calculateItemWidth(containerWidth: currentViewSize.width, numberOfItems: 4)
                return NSSize(width: bestItemWidth, height: bestItemWidth / itemRatio)
            } else {
                let bestItemWidth = calculateItemWidth(containerWidth: currentViewSize.width, numberOfItems: 5)
                return NSSize(width: bestItemWidth, height: bestItemWidth / itemRatio)
            }
        }
        
        func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
            return AppContentGridView.gridPadding
        }
        
        func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
            return AppContentGridView.gridPadding
        }
        
        private func calculateItemWidth(containerWidth: CGFloat, numberOfItems: Int) -> CGFloat {
            let minimumItemWidth: CGFloat = AppContentGridView.gridItemMinWidth
            let maximumItemWidth: CGFloat = AppContentGridView.gridItemMaxWidth
            let minimumContainerWidth: CGFloat = PlanetUI.CROPTOP_WINDOW_CONTENT_WIDTH_MIN - AppContentGridView.gridPadding * 2
            let padding: CGFloat = AppContentGridView.gridPadding
            let availableWidth = containerWidth - CGFloat(numberOfItems + 1) * padding
            let itemWidth = max(minimumItemWidth, min(maximumItemWidth, availableWidth / CGFloat(numberOfItems)))
            if containerWidth < minimumContainerWidth {
                let adjustedPadding = (containerWidth - CGFloat(numberOfItems) * itemWidth) / CGFloat(numberOfItems + 1)
                let targetWidth = max(minimumItemWidth, min(maximumItemWidth, itemWidth + adjustedPadding))
                return targetWidth
            }
            return itemWidth
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self, articles: planet.articles)
    }
    
    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> some NSScrollView {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.sectionInset = .init(top: AppContentGridView.gridPadding, left: AppContentGridView.gridPadding, bottom: AppContentGridView.gridPadding, right: AppContentGridView.gridPadding)
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
            collectionView.reloadData()
        }
    }
}
