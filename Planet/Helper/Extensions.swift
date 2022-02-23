//
//  Extensions.swift
//  Planet
//
//  Created by Kai on 11/10/21.
//

import Foundation
import Cocoa


extension String {
    static let currentUUIDKey: String = "PlanetCurrentUUIDKey"
    static let settingsLaunchOptionKey = "PlanetUserDefaultsLaunchOptionKey"
}


extension Notification.Name {
    static let killHelper = Notification.Name("PlanetKillPlanetHelperNotification")
    static let terminateDaemon = Notification.Name("PlanetTerminatePlanetDaemonNotification")
    static let closeWriterWindow = Notification.Name("PlanetCloseWriterWindowNotification")
}


extension Date {
    func dateDescription() -> String {
        let format = DateFormatter()
        format.dateStyle = .short
        format.timeStyle = .medium
        return format.string(from: self)
    }
}


extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}


protocol URLQueryParameterStringConvertible {
    var queryParameters: String {get}
}


extension Dictionary : URLQueryParameterStringConvertible {
    var queryParameters: String {
        var parts: [String] = []
        for (key, value) in self {
            let part = String(format: "%@=%@",
                String(describing: key).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!,
                String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
            parts.append(part as String)
        }
        return parts.joined(separator: "&")
    }
    
}


extension URL {
    func appendingQueryParameters(_ parametersDictionary : Dictionary<String, String>) -> URL {
        let URLString : String = String(format: "%@?%@", self.absoluteString, parametersDictionary.queryParameters)
        return URL(string: URLString)!
    }
}
