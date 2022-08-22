//
//  DecentralizedApp.swift
//  Planet
//
//  Created by Xin Liu on 8/22/22.
//

import Foundation

// Example:
//
// name: 1inch
// link: 1inch.eth

class DecentralizedApp: Codable, Identifiable {
    let name: String
    let description: String?
    let link: String
    
    var id: String { name }
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case link
    }
}
