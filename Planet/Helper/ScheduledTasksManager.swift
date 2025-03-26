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
 Use this class to handle tasks that should run independently of any SwiftUI view lifecycle,
 such as checking for content updates, background data synchronization, or other system-level operations.
 For tasks that are directly tied to a view’s lifecycle, manage them within the view or its dedicated view model.
 */
class ScheduledTasksManager: ObservableObject {
    static let shared = ScheduledTasksManager()

    private var timer: Timer?
    private var tickCount = 0

    deinit {
        stopTasks()
    }
    
    func startTasks() {
        timer?.invalidate()
        tickCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tickCount += 1

            if self.tickCount % 600 == 0 {
                Task.detached {
                    await MainActor.run {
                        self.publishMyPlanets()
                    }
                }
            }
            
            if self.tickCount % 300 == 0 {
                Task.detached {
                    await MainActor.run {
                        self.updateFollowingPlanets()
                    }
                }
            }
            
            if self.tickCount % 60 == 0 {
                Task.detached {
                    await MainActor.run {
                        self.updateMyPlanetsTrafficAnalytics()
                    }
                }
            }
        }
    }
    
    func stopTasks() {
        timer?.invalidate()
        timer = nil
        tickCount = 0
    }

    // MARK: -
    // Publish my planets every 10 minutes
    @MainActor
    private func publishMyPlanets() {
        PlanetStore.shared.publishMyPlanets()
    }
    
    // Check content update every 5 minutes
    @MainActor
    private func updateFollowingPlanets() {
        PlanetStore.shared.updateFollowingPlanets()
    }
    
    // Get the latest analytics data every minute
    @MainActor
    private func updateMyPlanetsTrafficAnalytics() {
        PlanetStore.shared.updateMyPlanetsTrafficAnalytics()
    }
}
