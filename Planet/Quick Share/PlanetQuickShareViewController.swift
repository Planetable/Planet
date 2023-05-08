//
//  PlanetQuickShareViewController.swift
//  Planet
//
//  Created by Kai on 4/12/23.
//

import Foundation
import Cocoa
import SwiftUI


class PlanetQuickShareViewController: NSViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let contentView = NSHostingView(rootView:
                                            PlanetQuickShareView()
                                                .frame(width: .sheetWidth, height: .sheetHeight)
                                                .edgesIgnoringSafeArea(.vertical)
        )
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    override func loadView() {
        self.view = NSView()
        view.frame.size = CGSize(width: .sheetWidth, height: .sheetHeight)
        view.wantsLayer = true
    }

}
