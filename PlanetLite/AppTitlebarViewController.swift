//
//  AppTitlebarViewController.swift
//  Croptop
//

import Cocoa
import SwiftUI


class AppTitlebarViewController: NSViewController {
    
    var size: CGSize
    
    init(withSize size: CGSize) {
        self.size = size
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let contentView = NSHostingView(rootView: AppTitlebarView(size: size))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.setFrameSize(NSSize(width: size.width, height: size.height))
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
