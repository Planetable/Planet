//
//  WriterLLMViewModel.swift
//  Planet
//
//  Created by Kai on 5/14/25.
//

import Foundation
import SwiftUI


enum LLMQueryStatus: CustomStringConvertible, Hashable {
    case idle
    case sending
    case success
    case error(String)
    
    var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .sending:
            return "Sending..."
        case .success:
            return "Success"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}


class WriterLLMViewModel: NSObject, ObservableObject, URLSessionDataDelegate {
    static let llmServerSchemeKey = "PlanetLLMServerSchemeKey"
    static let llmServerURLKey = "PlanetLLMServerURLKey"
    static let llmServerPortKey = "PlanetLLMServerPortKey"
    static let llmSelectedModelKey = "PlanetLLMSelectedModelKey"
    
    @Published var serverScheme: String = UserDefaults.standard.string(forKey: WriterLLMViewModel.llmServerSchemeKey) ?? "http" {
        didSet {
            UserDefaults.standard.set(serverScheme, forKey: WriterLLMViewModel.llmServerSchemeKey)
        }
    }
    @Published var serverURL: String = UserDefaults.standard.string(forKey: WriterLLMViewModel.llmServerURLKey) ?? "localhost" {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: WriterLLMViewModel.llmServerURLKey)
        }
    }
    @Published var serverPort: String = UserDefaults.standard.string(forKey: WriterLLMViewModel.llmServerPortKey) ?? "1234" {
        didSet {
            UserDefaults.standard.set(serverPort, forKey: WriterLLMViewModel.llmServerPortKey)
        }
    }

    @Published var prompt: String = ""
    @Published var prompts: [String] = []
    @Published var result: String = ""
    @Published var rawResult: String = ""
    @Published var selectedModel: String = UserDefaults.standard.string(forKey: WriterLLMViewModel.llmSelectedModelKey) ?? "" {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: WriterLLMViewModel.llmSelectedModelKey)
        }
    }
    @Published var availableModels: [String] = [] {
        didSet {
            if availableModels.contains(selectedModel) {
                return
            }
            selectedModel = ""
        }
    }
    @Published var queryStatus: LLMQueryStatus = .idle
    
    private var currentTask: URLSessionTask?
    private var buffer = Data()
    private var streamingSession: URLSession?
    
    override init() {
        super.init()
        streamingSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        loadAvailableModels()
        loadPrompts()
    }

    func loadAvailableModels() {
        guard let url = URL(string: "\(serverScheme)://\(serverURL):\(serverPort)/v1/models") else {
            debugPrint("Invalid server url: http://\(serverURL):\(serverPort)/v1/models")
            DispatchQueue.main.async {
                self.selectedModel = ""
            }
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                debugPrint("Error fetching models: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.selectedModel = ""
                }
                return
            }
            guard let data = data else {
                debugPrint("No data returned from models endpoint.")
                DispatchQueue.main.async {
                    self?.selectedModel = ""
                }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let dataArray = json["data"] as? [[String: Any]] {
                    let models = dataArray.compactMap { $0["id"] as? String }
                    DispatchQueue.main.async {
                        self?.availableModels = models
                    }
                }
            } catch {
                debugPrint("Error parsing models JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.selectedModel = ""
                }
            }
        }
        task.resume()
    }

    func sendPrompt() {
        cancelCurrentRequest()

        guard let url = URL(string: "\(serverScheme)://\(serverURL):\(serverPort)/v1/completions") else {
            result = "Invalid API URL."
            queryStatus = .error("Invalid API URL.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // MARK: TODO: more prompt parameters
        let body: [String: Any] = [
            "model": selectedModel,
            "prompt": prompt,
            "temperature": 0.7,
            "stream": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            result = "Failed to encode request."
            queryStatus = .error("Failed to encode request.")
            return
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        queryStatus = .sending
        result = ""
        buffer = Data()

        let task = streamingSession?.dataTask(with: request)
        currentTask = task
        task?.resume()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        processServerData()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                if (error as NSError).code != NSURLErrorCancelled {
                    self.queryStatus = .error(error.localizedDescription)
                }
            } else {
                self.queryStatus = .success
            }
            if let dupIndex = self.prompts.firstIndex(of: self.prompt) {
                self.prompts.remove(at: dupIndex)
            }
            self.prompts.insert(self.prompt, at: 0)
            DispatchQueue.global(qos: .background).async {
                self.savePrompts()
            }
        }
    }
    
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
        queryStatus = .idle
    }
    
    // MARK: -
    
    private var promptsHistoryFileURL: URL {
        let llmURL = URLUtils.documentsPath.appendingPathComponent("Planet").appendingPathComponent("LLM")
        try? FileManager.default.createDirectory(at: llmURL, withIntermediateDirectories: true)
        let fileURL = llmURL.appendingPathComponent("prompts.json")
        return fileURL
    }
    
    private func loadPrompts() {
        do {
            let data = try Data(contentsOf: promptsHistoryFileURL)
            if let loadedPrompts = try JSONSerialization.jsonObject(with: data) as? [String] {
                DispatchQueue.main.async {
                    self.prompts = loadedPrompts
                }
            }
        } catch {
            debugPrint("Failed to load prompts: \(error.localizedDescription)")
        }
    }
    
    private func savePrompts() {
        do {
            let data = try JSONSerialization.data(withJSONObject: prompts, options: [])
            try data.write(to: promptsHistoryFileURL)
        } catch {
            debugPrint("Failed to save prompts: \(error.localizedDescription)")
        }
    }
    
    private func processServerData() {
        guard let str = String(data: buffer, encoding: .utf8) else { return }
        debugPrint("Received data: \(str)")
        let messages = str.components(separatedBy: "data: ")
        var lastProcessedIndex = 0

        for i in 0..<messages.count {
            let message = messages[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty { continue }
            if message == "[DONE]" {
                lastProcessedIndex = i + 1
                debugPrint("Received [DONE] signal")
                DispatchQueue.main.async {
                    self.queryStatus = .success
                }
                continue
            }
            if message.hasPrefix("{") && (message.hasSuffix("}") || message.hasSuffix("}\n")) {
                if let data = message.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let text = first["text"] as? String {
                    DispatchQueue.main.async {
                        self.result += text
                        self.rawResult += message + "\n"
                    }
                    lastProcessedIndex = i + 1
                } else {
                    debugPrint("Failed to parse JSON: \(message)")
                }
            } else {
                debugPrint("Incomplete JSON, keeping in buffer: \(message)")
                break
            }
        }
        if lastProcessedIndex < messages.count {
            let remainingMessages = Array(messages[lastProcessedIndex...])
            buffer = remainingMessages.joined(separator: "data: ").data(using: .utf8) ?? Data()
        } else {
            buffer = Data()
        }
    }
}
