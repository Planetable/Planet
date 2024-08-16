//
//  PlanetAPIConsoleViewController.swift
//  Planet
//

import Foundation
import Cocoa
import SwiftUI


class PlanetAPIConsoleViewController: NSViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView()
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = .clear
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let mainView = PlanetAPIConsoleView()
        let contentView = NSHostingView(rootView: mainView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        contentView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}
