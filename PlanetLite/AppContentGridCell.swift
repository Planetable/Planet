import Cocoa
import SwiftUI


class AppContentGridCell: NSCollectionViewItem {
    static let identifier: String = "AppCollectionCell"
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = .clear
    }
    
    func configureCell(_ article: MyArticleModel, size: NSSize) {
        for v in self.view.subviews {
            if v.isKind(of: NSHostingView<AppContentItemView>.self) {
                v.removeFromSuperview()
                break
            }
        }
        let contentView = NSHostingView(rootView:
            AppContentItemView(article: article, size: size).environmentObject(PlanetStore.shared)
        )
        contentView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(contentView)
        contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}
