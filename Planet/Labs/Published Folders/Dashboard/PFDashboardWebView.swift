//
//  PFDashboardWebView.swift
//  Planet
//
//  Created by Kai on 12/18/22.
//

import Cocoa
import WebKit


class PFDashboardWebView: WKWebView {

    init() {
        super.init(frame: CGRect(), configuration: WKWebViewConfiguration())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        for menuItem in menu.items {
            menuItem.isHidden = true
        }
    }
}
