//
//  CloudflarePages.swift
//  Planet
//

import CryptoKit
import Foundation
import UniformTypeIdentifiers
import os

struct CloudflarePages {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CloudflarePages")

    /// Max raw file data per upload batch (~10 MB; becomes ~14 MB after base64 + JSON overhead)
    private static let maxBatchSize = 10 * 1024 * 1024
    private static let rootHTMLMarker = "\n<!-- Planet Cloudflare Pages root -->\n"
    private static let tokenVerifyURL = URL(string: "https://api.cloudflare.com/client/v4/user/tokens/verify")!

    let accountID: String
    let apiToken: String
    let projectName: String

    private var baseURL: String {
        "https://api.cloudflare.com/client/v4/accounts/\(accountID)/pages/projects"
    }

    private var assetsBaseURL: String {
        "https://api.cloudflare.com/client/v4/pages/assets"
    }

    static func verifyAPIToken(_ apiToken: String) async -> Bool {
        let trimmedToken = apiToken.trim()
        guard !trimmedToken.isEmpty else {
            return false
        }

        var request = URLRequest(url: tokenVerifyURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            let verification = try JSONDecoder().decode(CloudflareTokenVerificationResponse.self, from: data)
            return verification.success
        } catch {
            logger.error("Cloudflare token verification failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Ensure the Pages project exists, creating it if needed.
    func ensureProjectExists() async throws {
        let url = URL(string: "\(baseURL)/\(projectName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        CloudflarePagesLogger.log("Checking if project '\(projectName)' exists")
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            CloudflarePagesLogger.log("Project '\(projectName)' exists")
            return
        }

        // Project doesn't exist — create it
        CloudflarePagesLogger.log("Creating project '\(projectName)'")
        let createURL = URL(string: baseURL)!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "name": projectName,
            "production_branch": "main",
        ]
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
        guard let createHTTP = createResponse as? HTTPURLResponse, createHTTP.statusCode == 200 else {
            let responseBody = String(data: createData, encoding: .utf8) ?? ""
            let message = "Failed to create project '\(projectName)': \(responseBody)"
            CloudflarePagesLogger.log("[ERROR] \(message)")
            throw PlanetError.CloudflarePagesPublishError(message)
        }
        CloudflarePagesLogger.log("Created project '\(projectName)'")
    }

    /// Deploy the contents of `directoryURL` to Cloudflare Pages via Direct Upload.
    ///
    /// Flow:
    /// 1. Get upload token (JWT) from the project
    /// 2. Check which file hashes are already uploaded
    /// 3. Upload only missing files in batches (base64 JSON)
    /// 4. Upsert hashes to register all files with CF
    /// 5. Create deployment with manifest only (multipart form)
    func deploy(directoryURL: URL) async throws -> URL? {
        try await ensureProjectExists()

        // Collect all files
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            let message = "Failed to enumerate files in \(directoryURL.path)"
            CloudflarePagesLogger.log("[ERROR] \(message)")
            throw PlanetError.CloudflarePagesPublishError(message)
        }

        var files: [(relativePath: String, url: URL)] = []
        while let fileURL = enumerator.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if resourceValues.isRegularFile == true {
                let relativePath = fileURL.path.replacingOccurrences(
                    of: directoryURL.path + "/",
                    with: ""
                )
                files.append((relativePath: "/" + relativePath, url: fileURL))
            }
        }

        // Pre-compute hashes, skip files over 25 MB (CF per-file limit)
        let maxFileSize = 25 * 1024 * 1024
        var fileEntries: [(relativePath: String, data: Data, hash: String, contentType: String)] = []
        var manifest: [String: String] = [:]
        var skippedCount = 0
        for file in files {
            let fileData = try Self.preparedFileData(for: file)
            if fileData.count > maxFileSize {
                skippedCount += 1
                CloudflarePagesLogger.log(
                    "[WARNING] Skipping \(file.relativePath) (\(ByteCountFormatter.string(fromByteCount: Int64(fileData.count), countStyle: .file))) — exceeds 25 MB Cloudflare Pages limit"
                )
                continue
            }
            let hash = Self.assetHash(for: fileData)
            let contentType = Self.mimeType(for: file.url)
            manifest[file.relativePath] = hash
            fileEntries.append((relativePath: file.relativePath, data: fileData, hash: hash, contentType: contentType))
        }

        if skippedCount > 0 {
            CloudflarePagesLogger.log("[WARNING] Skipped \(skippedCount) file(s) exceeding 25 MB limit")
        }
        CloudflarePagesLogger.log(
            "Deploying \(fileEntries.count) files to project '\(projectName)'"
        )

        // Step 1: Get upload token (JWT)
        let jwt = try await getUploadToken()
        CloudflarePagesLogger.log("Obtained upload token")

        // Step 2: Check which files need uploading
        let allHashes = Array(Set(fileEntries.map { $0.hash }))
        let missingHashes = try await checkMissingFiles(hashes: allHashes, jwt: jwt)
        CloudflarePagesLogger.log("\(missingHashes.count) of \(allHashes.count) unique files need uploading")

        // Step 3: Upload missing files in batches
        if !missingHashes.isEmpty {
            let missingSet = Set(missingHashes)
            // Deduplicate by hash
            var seen = Set<String>()
            var filesToUpload: [(relativePath: String, data: Data, hash: String, contentType: String)] = []
            for file in fileEntries {
                if missingSet.contains(file.hash) && !seen.contains(file.hash) {
                    seen.insert(file.hash)
                    filesToUpload.append(file)
                }
            }
            try await uploadFiles(files: filesToUpload, jwt: jwt)
        }

        // Step 4: Upsert hashes to register all files
        try await upsertHashes(hashes: allHashes, jwt: jwt)

        // Step 5: Create deployment with manifest only
        let siteURL = try await createDeployment(manifest: manifest)

        CloudflarePagesLogger.log("Deployed to project '\(projectName)' successfully")
        return siteURL
    }

    // MARK: - Private helpers

    /// Get a JWT upload token for the project.
    private func getUploadToken() async throws -> String {
        let url = URL(string: "\(baseURL)/\(projectName)/upload-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = "Failed to get upload token (HTTP \(statusCode)): \(responseBody)"
            CloudflarePagesLogger.log("[ERROR] \(message)")
            throw PlanetError.CloudflarePagesPublishError(message)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let jwt = result["jwt"] as? String else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            let message = "Failed to parse upload token: \(responseBody)"
            CloudflarePagesLogger.log("[ERROR] \(message)")
            throw PlanetError.CloudflarePagesPublishError(message)
        }

        return jwt
    }

    /// Check which file hashes are missing on the server.
    private func checkMissingFiles(hashes: [String], jwt: String) async throws -> [String] {
        let url = URL(string: "\(assetsBaseURL)/check-missing")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["hashes": hashes]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = "Failed to check missing files (HTTP \(statusCode)): \(responseBody)"
            CloudflarePagesLogger.log("[ERROR] \(message)")
            throw PlanetError.CloudflarePagesPublishError(message)
        }

        // Try CF v4 envelope format first, then bare array
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = json["result"] as? [String] {
            return result
        }
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return arr
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""
        let message = "Unexpected check-missing response: \(responseBody)"
        CloudflarePagesLogger.log("[ERROR] \(message)")
        throw PlanetError.CloudflarePagesPublishError(message)
    }

    /// Register all file hashes with CF after uploading.
    private func upsertHashes(hashes: [String], jwt: String) async throws {
        let url = URL(string: "\(assetsBaseURL)/upsert-hashes")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["hashes": hashes]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = "Failed to upsert hashes (HTTP \(statusCode)): \(responseBody)"
            CloudflarePagesLogger.log("[ERROR] \(message)")
            throw PlanetError.CloudflarePagesPublishError(message)
        }
        CloudflarePagesLogger.log("Upserted \(hashes.count) hashes")
    }

    /// Upload files in batches to the assets endpoint.
    private func uploadFiles(
        files: [(relativePath: String, data: Data, hash: String, contentType: String)],
        jwt: String
    ) async throws {
        var batches: [[(relativePath: String, data: Data, hash: String, contentType: String)]] = []
        var currentBatch: [(relativePath: String, data: Data, hash: String, contentType: String)] = []
        var currentSize = 0

        for file in files {
            if currentSize + file.data.count > Self.maxBatchSize && !currentBatch.isEmpty {
                batches.append(currentBatch)
                currentBatch = []
                currentSize = 0
            }
            currentBatch.append(file)
            currentSize += file.data.count
        }
        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }

        CloudflarePagesLogger.log("Uploading \(files.count) files in \(batches.count) batch(es)")

        for i in 0..<batches.count {
            try await uploadBatch(files: batches[i], jwt: jwt, index: i + 1, total: batches.count)
        }
    }

    /// Upload a single batch as a JSON array of base64-encoded files.
    private func uploadBatch(
        files: [(relativePath: String, data: Data, hash: String, contentType: String)],
        jwt: String,
        index: Int,
        total: Int
    ) async throws {
        let totalBytes = files.reduce(0) { $0 + $1.data.count }
        CloudflarePagesLogger.log(
            "Uploading batch \(index)/\(total): \(files.count) files, \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file))"
        )

        let url = URL(string: "\(assetsBaseURL)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [[String: Any]] = files.map { file in
            [
                "key": file.hash,
                "value": file.data.base64EncodedString(),
                "metadata": ["contentType": file.contentType],
                "base64": true,
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseBody = String(data: responseData, encoding: .utf8) ?? ""
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = "Upload batch \(index)/\(total) failed (HTTP \(statusCode)): \(responseBody)"
            CloudflarePagesLogger.log("[ERROR] \(message)")
            throw PlanetError.CloudflarePagesPublishError(message)
        }
        CloudflarePagesLogger.log("Batch \(index)/\(total) uploaded")
    }

    /// Create the deployment with the manifest (files already uploaded).
    private func createDeployment(manifest: [String: String]) async throws -> URL? {
        let url = URL(string: "\(baseURL)/\(projectName)/deployments")!
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        let manifestJSON = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])

        var bodyData = Data()
        bodyData.appendMultipart(
            name: "manifest",
            fileName: nil,
            contentType: "text/plain",
            data: manifestJSON,
            boundary: boundary
        )
        bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = bodyData

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseBody = String(data: responseData, encoding: .utf8) ?? ""
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = "Failed to create deployment (HTTP \(statusCode)): \(responseBody)"
            CloudflarePagesLogger.log("[ERROR] \(message)")
            throw PlanetError.CloudflarePagesPublishError(message)
        }
        let deployment = Self.parseDeployment(from: responseData)
        let siteURL = Self.resolvedProductionSiteURL(from: deployment)
        if let deploymentURL = deployment?.url, let siteURL {
            CloudflarePagesLogger.log(
                "Deployment created: deployment=\(deploymentURL.absoluteString) site=\(siteURL.absoluteString)"
            )
        } else if let deploymentURL = deployment?.url {
            CloudflarePagesLogger.log(
                "[WARNING] Deployment created but response did not include a stable production Pages URL: deployment=\(deploymentURL.absoluteString)"
            )
        } else if let siteURL {
            CloudflarePagesLogger.log("Deployment created: site=\(siteURL.absoluteString)")
        } else {
            CloudflarePagesLogger.log(
                "[WARNING] Deployment created but response did not include a usable Pages URL"
            )
        }
        return siteURL
    }

    /// Cloudflare's asset store expects 32 hexadecimal characters per content key.
    private static func assetHash(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        let fullHash = digest.compactMap { String(format: "%02x", $0) }.joined()
        return String(fullHash.prefix(32))
    }

    private static func preparedFileData(for file: (relativePath: String, url: URL)) throws -> Data {
        let data = try Data(contentsOf: file.url)
        guard file.relativePath == "/index.html",
              var html = String(data: data, encoding: .utf8) else {
            return data
        }
        if !html.contains(rootHTMLMarker) {
            html += rootHTMLMarker
        }
        return Data(html.utf8)
    }

    private static func parseDeployment(from data: Data) -> PagesDeployment? {
        try? JSONDecoder().decode(PagesDeploymentEnvelope.self, from: data).result
    }

    private static func resolvedProductionSiteURL(from deployment: PagesDeployment?) -> URL? {
        if let deployment {
            if let aliasURL = deployment.aliases?.lazy.compactMap(Self.pagesURL(from:)).first {
                return aliasURL
            }
            if let deploymentURL = deployment.url,
               let derivedURL = Self.pagesURL(
                from: deploymentURL,
                environment: deployment.environment
               ) {
                return derivedURL
            }
        }
        return nil
    }

    private static func pagesURL(from alias: String) -> URL? {
        let trimmed = alias.trim()
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let host = url.host?.lowercased(), host.hasSuffix(".pages.dev") {
            return URL(string: "https://\(host)/")
        }
        let host = trimmed.lowercased()
        guard host.hasSuffix(".pages.dev") else { return nil }
        return URL(string: "https://\(host)/")
    }

    private static func pagesURL(from deploymentURL: URL, environment: String?) -> URL? {
        guard let host = deploymentURL.host?.lowercased(),
              host.hasSuffix(".pages.dev")
        else {
            return nil
        }

        let components = host.split(separator: ".")
        let resolvedHost: String
        if environment?.lowercased() == "production", components.count >= 4 {
            resolvedHost = components.dropFirst().joined(separator: ".")
        } else {
            resolvedHost = host
        }
        return URL(string: "https://\(resolvedHost)/")
    }
    /// Determine MIME type for a file URL based on its extension.
    private static func mimeType(for url: URL) -> String {
        if let utType = UTType(filenameExtension: url.pathExtension),
           let mime = utType.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
}

private struct PagesDeploymentEnvelope: Decodable {
    let result: PagesDeployment
}

private struct CloudflareTokenVerificationResponse: Decodable {
    let success: Bool
}

private struct PagesDeployment: Decodable {
    let projectName: String?
    let environment: String?
    let url: URL?
    let aliases: [String]?

    enum CodingKeys: String, CodingKey {
        case projectName = "project_name"
        case environment
        case url
        case aliases
    }
}

private extension Data {
    mutating func appendMultipart(
        name: String,
        fileName: String?,
        contentType: String,
        data: Data,
        boundary: String
    ) {
        var header = "--\(boundary)\r\n"
        if let fileName = fileName {
            header += "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n"
        } else {
            header += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        }
        header += "Content-Type: \(contentType)\r\n\r\n"
        append(header.data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
