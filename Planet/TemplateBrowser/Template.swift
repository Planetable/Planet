//
//  Template.swift
//  Planet
//
//  Created by Livid on 5/3/22.
//

import Foundation

struct Template: Codable, Identifiable, Hashable {
    var name: String
    var id: String { "\(name)" }
    var description: String
    var path: URL?
    var blogPath: URL?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
    }

    init?(url: URL) {
        let templateInfoPath = url.appendingPathComponent("template.json")
        if FileManager.default.fileExists(atPath: templateInfoPath.path) {
            let blogPath = url.appendingPathComponent("templates").appendingPathComponent("blog.html")
            if FileManager.default.fileExists(atPath: blogPath.path) {
                self.blogPath = blogPath
            } else {
                debugPrint("Directory has no blog.html: \(url.path)")
                return nil
            }
            do {
                let data = try Data(contentsOf: templateInfoPath)
                let decoder = JSONDecoder()
                let template = try decoder.decode(Template.self, from: data)
                self.name = template.name
                self.description = template.description
                self.path = url
            } catch {
                debugPrint("Failed to load template info for \(url.lastPathComponent)")
                return nil
            }
        } else {
            return nil
        }
    }
    
    // TODO: render func goes here
}
