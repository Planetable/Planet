//
//  ScheduledTasksManager.swift
//  Planet
//
//  Created by Kai on 3/26/25.
//

import Foundation
import SwiftUI
import Combine


/**
 Global tasks manager for system-wide scheduled operations.
 Use this class to handle tasks that should run independently of any SwiftUI view lifecycle, such as checking for content updates, background data synchronization, or other system-level operations.
 For tasks that are directly tied to a view’s lifecycle, manage them within the view or its dedicated view model.
 */
class ScheduledTasksManager: ObservableObject {
    static let shared = ScheduledTasksManager()
}
