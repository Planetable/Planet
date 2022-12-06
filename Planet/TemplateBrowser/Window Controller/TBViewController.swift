//
//  TBViewController.swift
//  Planet
//
//  Created by Kai on 12/5/22.
//

import Cocoa
import SwiftUI


class TBViewController: NSViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let contentView = NSHostingView(rootView: TemplatePreviewView())
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = .clear
    }

}
