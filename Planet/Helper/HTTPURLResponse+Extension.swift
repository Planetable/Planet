//
//  HTTPURLResponse+Extension.swift
//  Planet
//
//  Created by Shu Lyu on 2022-04-06.
//

import Foundation

extension HTTPURLResponse {
    var ok: Bool {
        return self.statusCode >= 200 && self.statusCode < 300
    }
}
