//
//  Plausible.swift
//  Planet
//
//  Created by Xin Liu on 9/21/22.
//

import Foundation
import SwiftyJSON

struct PlausibleAnalytics {
    let domain: String
    let apiKey: String
    let apiServer: String

    func updateTrafficAnalytics(for planet: MyPlanetModel) async {
        let url = URL(
            string:
                "https://\(apiServer)/api/v1/stats/aggregate?site_id=\(domain)&period=day&metrics=visitors,pageviews"
        )!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            return
        }
        do {
            let json = try JSON(data: data)
            if let visitors = json["results"]["visitors"]["value"].int,
                let pageviews = json["results"]["pageviews"]["value"].int
            {
                if planet.metrics == nil {
                    Task { @MainActor in
                        planet.metrics = Metrics(
                            visitorsToday: visitors,
                            pageviewsToday: pageviews
                        )
                    }
                }
                else {
                    Task { @MainActor in
                        planet.metrics?.visitorsToday = visitors
                        planet.metrics?.pageviewsToday = pageviews
                    }
                }
            }
        }
        catch {
            debugPrint(
                "Plausible: error occurred when fetching analytics for \(planet.name) \(error)"
            )
        }
    }
}

struct Metrics: Codable {
    var visitorsToday: Int
    var pageviewsToday: Int
}
