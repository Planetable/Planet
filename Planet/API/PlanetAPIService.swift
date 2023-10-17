//
//  PlanetAPIService.swift
//  Planet
//
//  Created by Xin Liu on 10/16/23.
//

import Foundation

/// Bonjour service for API autodiscovery
class PlanetAPIService: NSObject, NetServiceDelegate {
    private var netService: NetService!

    override init() {
        super.init()
        setupService()
    }
    
    init(_ port: Int) {
        super.init()
        setupService(port)
    }

    private func setupService(_ port: Int = 9191) {
        // Initialize NetService object with domain, service type, name, and port.
        netService = NetService(domain: "local.", type: "_http._tcp.", name: "Planet API Server", port: Int32(port))

        // Set the delegate for the NetService object to self.
        netService.delegate = self
        netService.includesPeerToPeer = true

        debugPrint("About to publish Bonjour service: \(netService)")
        // Publish the service to the network.
        netService.publish()
    }

    // MARK: - NetServiceDelegate methods
    public func netServiceDidPublish(_ sender: NetService) {
        debugPrint("Successfully published Bonjour service: \(sender)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        debugPrint("Failed to publish Bonjour service: \(errorDict)")
    }
}
