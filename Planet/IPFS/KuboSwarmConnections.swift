//
//  KuboSwarmConnections.swift
//  Planet
//
//  Created by Xin Liu on 5/8/25.
//

enum KuboSwarmConnections {
    case low
    case medium
    case high

    var range: ClosedRange<Int> {
        switch self {
        case .low:
            return 10...20
        case .medium:
            return 20...40
        case .high:
            return 50...100
        }
    }
}
