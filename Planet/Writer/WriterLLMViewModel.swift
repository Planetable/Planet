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
    static let llmServerKey = "PlanetLLMServerKey"
    static let llmSelectedModelKey = "PlanetLLMSelectedModelKey"
    
    @Published var server: String = UserDefaults.standard.string(forKey: WriterLLMViewModel.llmServerKey) ?? "http://localhost:1234" {
        didSet {
            UserDefaults.standard.set(server, forKey: WriterLLMViewModel.llmServerKey)
        }
    }
    @Published var prompt: String = ""
    @Published var prompts: [String] = []
    @Published var result: String = ""
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
        guard let url = URL(string: "\(server)/api/v0/models") else {
            debugPrint("Invalid server: \(server)/api/v0/models")
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
                    let models = dataArray.compactMap { dict -> String? in
                        guard
                            let id   = dict["id"]   as? String,
                            let type = dict["type"] as? String,
                            type == "llm"
                        else { return nil }
                        return id
                    }
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

        guard let url = URL(string: "\(server)/v1/completions") else {
            result = "Invalid API URL."
            queryStatus = .error("Invalid API URL.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Enhanced prompt parameters based on LM Studio reference
        let body: [String: Any] = [
            "model": selectedModel,
            "prompt": prompt,
            // Core generation parameters
            "temperature": 0.7,
            "top_p": 0.9,
            "top_k": 40,
            "repeat_penalty": 1.15,
            "frequency_penalty": 0.0,
            "presence_penalty": 0.0,
            // Control the length of generation
            "max_tokens": 2048,
            // Special tokens handling
            "stop": ["<|eot_id|>", "<|eom_id|>", "<|eom|>"],
            // Context handling
            "context_length": 4096,
            // Stream response for real-time updates
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
        guard let str = String(data: buffer, encoding: .utf8) else { 
            debugPrint("Failed to decode buffer data with UTF-8 encoding")
            return 
        }
        
        let messages = str.components(separatedBy: "data: ")
        var lastProcessedIndex = 0

        for i in 0..<messages.count {
            let message = messages[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if message.isEmpty { continue }
            
            // Handle completion marker
            if message == "[DONE]" {
                lastProcessedIndex = i + 1
                DispatchQueue.main.async {
                    self.queryStatus = .success
                }
                continue
            }
            
            // Process JSON responses
            if message.hasPrefix("{") && (message.hasSuffix("}") || message.hasSuffix("}\n")) {
                if let data = message.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // Extract more information from the response
                    let choices = json["choices"] as? [[String: Any]] ?? []
                    let first = choices.first
                    let text = first?["text"] as? String ?? ""
                    let finishReason = first?["finish_reason"] as? String
                    
                    // Extract token usage information if available
                    if let usage = json["usage"] as? [String: Any] {
                        let promptTokens = usage["prompt_tokens"] as? Int
                        let completionTokens = usage["completion_tokens"] as? Int
                        let totalTokens = usage["total_tokens"] as? Int
                        
                        // Log token usage for metrics
                        if let prompt = promptTokens, let completion = completionTokens, let total = totalTokens {
                            debugPrint("Token usage - Prompt: \(prompt), Completion: \(completion), Total: \(total)")
                        }
                    }
                    
                    // Handle different finish reasons
                    if let reason = finishReason {
                        switch reason {
                        case "stop":
                            // Normal stop - model reached a natural stopping point
                            break
                        case "length":
                            // Model reached max tokens - might be incomplete
                            debugPrint("Warning: Response truncated due to max token limit")
                        case "content_filter":
                            // Content was filtered due to safety settings
                            debugPrint("Warning: Response filtered due to content guidelines")
                        default:
                            debugPrint("Finish reason: \(reason)")
                        }
                    }
                    
                    // Update the UI with the new text
                    DispatchQueue.main.async {
                        if !text.isEmpty {
                            self.result += text
                        }
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
        
        // Update buffer with any remaining unprocessed data
        if lastProcessedIndex < messages.count {
            let remainingMessages = Array(messages[lastProcessedIndex...])
            buffer = remainingMessages.joined(separator: "data: ").data(using: .utf8) ?? Data()
        } else {
            buffer = Data()
        }
    }
}
