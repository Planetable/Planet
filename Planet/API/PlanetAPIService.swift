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

    func stopService() {
        netService?.stop()
        netService?.delegate = nil
        netService = nil
    }

    private func getHostname() -> String? {
        var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if gethostname(&name, name.count) == 0 {
            let hostname = String(cString: name)
            return hostname
        }
        else {
            return nil
        }
    }

    private func setupService(_ port: Int = 8086) {
        // Initialize NetService object with domain, service type, name, and port.
        var serviceName: String
        if Bundle.main.executableURL?.lastPathComponent == "Croptop" {
            serviceName = "Croptop"
        } else {
            serviceName = "Planet"
        }
        if let hostname = getHostname() {
            serviceName = serviceName + " on \(hostname)"
        }
        netService = NetService(
            domain: "local.",
            type: "_planet._tcp.",
            name: serviceName,
            port: Int32(port)
        )

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

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        debugPrint("Failed to publish Bonjour service: \(errorDict)")
    }
    
    func netServiceDidStop(_ sender: NetService) {
        debugPrint("Bonjour service stopped.")
    }
}
