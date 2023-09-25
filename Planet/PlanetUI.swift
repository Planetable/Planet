//
//  PlanetUI.swift
//  Planet
//
//  Created by Xin Liu on 11/16/22.
//

import Foundation

struct PlanetUI {
    static let SHEET_WIDTH_LARGE: CGFloat = 720
    static let SHEET_WIDTH_PROGRESS_VIEW: CGFloat = 300
    static let SHEET_WIDTH_REBUILD_VIEW: CGFloat = 360

    static let SHEET_PADDING: CGFloat = 20

    static let CONTROL_ROW_SPACING: CGFloat = 8 // For VStack(spacing:) in forms
    static let CONTROL_ITEM_GAP: CGFloat = 8

    // For 3-column NSWindowController-based windows
    static let WINDOW_SIDEBAR_WIDTH_MIN: CGFloat = 200
    static let WINDOW_SIDEBAR_WIDTH_MAX: CGFloat = 280
    static let WINDOW_INSPECTOR_WIDTH_MIN: CGFloat = 200
    static let WINDOW_INSPECTOR_WIDTH_MAX: CGFloat = 280
    static let WINDOW_CONTENT_WIDTH_MIN: CGFloat = 400
    static let WINDOW_CONTENT_HEIGHT_MIN: CGFloat = 400
    
    // Croptop 2-column NSWindowController-based windows
    static let CROPTOP_WINDOW_CONTENT_WIDTH_MIN: CGFloat = 460
    static let CROPTOP_WINDOW_CONTENT_HEIGHT_MIN: CGFloat = 474
}
