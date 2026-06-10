import Foundation

struct PNMultipartFile {
    let fieldName: String
    let url: URL
    let contentType: String
}

final class PNAPIClient {
    let baseURL: URL
    let timeout: TimeInterval

    init(baseURL: URL, timeout: TimeInterval) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    func ping() -> Bool {
        do {
            let text = try requestText(method: "GET", path: ["v0", "ping"])
            return text.pnTrimmed == "pong"
        } catch {
            return false
        }
    }

    func waitUntilReachable(seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            if ping() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return false
    }

    func planets(includeArchived: Bool = false, archivedOnly: Bool = false) throws -> [PNPlanetRecord] {
        var query: [String: String] = [:]
        if archivedOnly {
            query["archived"] = "true"
        } else if includeArchived {
            query["all"] = "true"
        }
        return try requestJSON([PNPlanetRecord].self, method: "GET", path: ["v0", "planets", "my"], query: query)
    }

    func planet(id: UUID) throws -> PNPlanetRecord {
        try requestJSON(PNPlanetRecord.self, method: "GET", path: ["v0", "planets", "my", id.uuidString])
    }

    func createPlanet(name: String, about: String?, template: String?, avatar: URL?) throws -> PNPlanetRecord {
        if let avatar {
            return try requestMultipart(
                PNPlanetRecord.self,
                method: "POST",
                path: ["v0", "planets", "my"],
                fields: [
                    "name": name,
                    "about": about ?? "",
                    "template": template ?? ""
                ],
                files: [PNMultipartFile(fieldName: "avatar", url: avatar, contentType: Self.mimeType(for: avatar))]
            )
        }
        return try requestJSON(
            PNPlanetRecord.self,
            method: "POST",
            path: ["v0", "planets", "my"],
            json: ["name": name, "about": about ?? "", "template": template ?? ""]
        )
    }

    func updatePlanet(id: UUID, name: String?, about: String?, template: String?, avatar: URL?) throws -> PNPlanetRecord {
        if let avatar {
            var fields: [String: String] = [:]
            if let name { fields["name"] = name }
            if let about { fields["about"] = about }
            if let template { fields["template"] = template }
            return try requestMultipart(
                PNPlanetRecord.self,
                method: "POST",
                path: ["v0", "planets", "my", id.uuidString],
                fields: fields,
                files: [PNMultipartFile(fieldName: "avatar", url: avatar, contentType: Self.mimeType(for: avatar))]
            )
        }
        var json: [String: String] = [:]
        if let name { json["name"] = name }
        if let about { json["about"] = about }
        if let template { json["template"] = template }
        return try requestJSON(PNPlanetRecord.self, method: "POST", path: ["v0", "planets", "my", id.uuidString], json: json)
    }

    func deletePlanet(id: UUID) throws -> PNPlanetRecord {
        try requestJSON(PNPlanetRecord.self, method: "DELETE", path: ["v0", "planets", "my", id.uuidString])
    }

    func publishPlanet(id: UUID) throws -> PNPlanetRecord {
        try requestJSON(PNPlanetRecord.self, method: "POST", path: ["v0", "planets", "my", id.uuidString, "publish"])
    }

    func articles(planetID: UUID) throws -> [PNArticleRecord] {
        do {
            return try requestJSON([PNArticleRecord].self, method: "GET", path: ["v0", "planets", "my", planetID.uuidString, "articles"])
        } catch PNError.apiError(404, let body) {
            // The API returns a plain 404 for a planet with zero articles, and
            // a reasoned 404 when the planet itself is missing.
            guard !body.contains("Planet not found") else {
                throw PNError.notFound("Planet not found via API: \(planetID.uuidString)")
            }
            return []
        }
    }

    func article(planetID: UUID, articleID: UUID) throws -> PNArticleRecord {
        try requestJSON(
            PNArticleRecord.self,
            method: "GET",
            path: ["v0", "planets", "my", planetID.uuidString, "articles", articleID.uuidString]
        )
    }

    func createArticle(planetID: UUID, title: String, content: String, date: Date?, attachments: [URL]) throws -> PNArticleRecord {
        let fields = articleFields(title: title, content: content, date: date)
        if attachments.isEmpty {
            return try requestJSON(PNArticleRecord.self, method: "POST", path: ["v0", "planets", "my", planetID.uuidString, "articles"], json: fields)
        }
        return try requestMultipart(
            PNArticleRecord.self,
            method: "POST",
            path: ["v0", "planets", "my", planetID.uuidString, "articles"],
            fields: fields,
            files: attachments.map { PNMultipartFile(fieldName: "attachment", url: $0, contentType: Self.mimeType(for: $0)) }
        )
    }

    func updateArticle(planetID: UUID, articleID: UUID, title: String?, content: String?, date: Date?, replaceAttachments: Bool, attachments: [URL]) throws -> PNArticleRecord {
        var fields: [String: String] = [:]
        if let title { fields["title"] = title }
        if let content { fields["content"] = content }
        if let date { fields["date"] = PNDateParser.format(date) }
        if replaceAttachments || !attachments.isEmpty {
            return try requestMultipart(
                PNArticleRecord.self,
                method: "POST",
                path: ["v0", "planets", "my", planetID.uuidString, "articles", articleID.uuidString],
                fields: fields,
                files: attachments.map { PNMultipartFile(fieldName: "attachment", url: $0, contentType: Self.mimeType(for: $0)) }
            )
        }
        return try requestJSON(
            PNArticleRecord.self,
            method: "POST",
            path: ["v0", "planets", "my", planetID.uuidString, "articles", articleID.uuidString],
            json: fields
        )
    }

    func deleteArticle(planetID: UUID, articleID: UUID) throws -> PNArticleRecord {
        try requestJSON(
            PNArticleRecord.self,
            method: "DELETE",
            path: ["v0", "planets", "my", planetID.uuidString, "articles", articleID.uuidString]
        )
    }

    func search(query: String, limit: Int) throws -> PNSearchResponse {
        try requestJSON(PNSearchResponse.self, method: "GET", path: ["v0", "search"], query: ["q": query, "limit": String(limit)])
    }

    private func articleFields(title: String, content: String, date: Date?) -> [String: String] {
        var fields = ["title": title, "content": content]
        if let date {
            fields["date"] = PNDateParser.format(date)
        }
        return fields
    }

    private func requestJSON<T: Decodable>(
        _ type: T.Type,
        method: String,
        path: [String],
        query: [String: String] = [:],
        json: [String: String]? = nil
    ) throws -> T {
        var request = try makeRequest(method: method, path: path, query: query)
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json, options: [])
        }
        let data = try perform(request)
        return try PNJSON.decoder.decode(type, from: data)
    }

    private func requestText(method: String, path: [String]) throws -> String {
        let request = try makeRequest(method: method, path: path)
        let data = try perform(request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func requestMultipart<T: Decodable>(
        _ type: T.Type,
        method: String,
        path: [String],
        fields: [String: String],
        files: [PNMultipartFile]
    ) throws -> T {
        let boundary = "pn-\(UUID().uuidString)"
        var request = try makeRequest(method: method, path: path)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(boundary: boundary, fields: fields, files: files)
        let data = try perform(request)
        return try PNJSON.decoder.decode(type, from: data)
    }

    private func makeRequest(method: String, path: [String], query: [String: String] = [:]) throws -> URLRequest {
        var url = baseURL
        for component in path {
            url.appendPathComponent(component)
        }
        if !query.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw PNError.runtime("Unable to build API URL.")
            }
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let queryURL = components.url else {
                throw PNError.runtime("Unable to build API query URL.")
            }
            url = queryURL
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        if PNPreferences.apiUsesPasscode() {
            let username = PNPreferences.apiUsername()
            let password = try PNKeychain.apiPasscode()
            let token = "\(username):\(password)".data(using: .utf8)?.base64EncodedString() ?? ""
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(_ request: URLRequest) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<(Data, URLResponse), Error>?
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                result = .failure(error)
            } else if let response {
                result = .success((data ?? Data(), response))
            } else {
                result = .failure(PNError.apiUnavailable("Planet API did not return a response."))
            }
            semaphore.signal()
        }.resume()

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw PNError.apiUnavailable("Timed out waiting for Planet API at \(baseURL.absoluteString).")
        }
        guard let result else {
            throw PNError.apiUnavailable("Planet API did not return a response.")
        }
        let (data, response) = try result.get()
        guard let http = response as? HTTPURLResponse else {
            throw PNError.apiUnavailable("Planet API did not return an HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PNError.apiError(http.statusCode, body.pnTrimmed)
        }
        return data
    }

    private func multipartBody(boundary: String, fields: [String: String], files: [PNMultipartFile]) throws -> Data {
        var body = Data()
        func append(_ string: String) {
            body.append(Data(string.utf8))
        }

        for (name, value) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append(value)
            append("\r\n")
        }

        for file in files {
            let data = try Data(contentsOf: file.url)
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.url.lastPathComponent)\"\r\n")
            append("Content-Type: \(file.contentType)\r\n\r\n")
            body.append(data)
            append("\r\n")
        }

        append("--\(boundary)--\r\n")
        return body
    }

    static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "heic":
            return "image/heic"
        case "mp4", "m4v":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "mp3":
            return "audio/mpeg"
        case "m4a":
            return "audio/mp4"
        case "pdf":
            return "application/pdf"
        default:
            return "application/octet-stream"
        }
    }
}
