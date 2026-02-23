//
//  ArticleAIChatView.swift
//  Planet
//
//  Created by Xin Liu on 2/23/26.
//

import SwiftUI


private struct ArticleAIChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let tokenUsage: String?
}

struct ArticleAIChatPersistedMessage: Codable {
    let role: String
    let content: String
    let tokenUsage: String?
}

struct ArticleAIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var article: ArticleModel

    @State private var messages: [ArticleAIChatMessage] = []
    @State private var apiMessages: [[String: String]] = []
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var errorText: String? = nil
    @State private var shouldAnimateScroll: Bool = false
    @State private var chatFontSize: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("AI Research Chat", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                }
                ControlGroup {
                    Button {
                        chatFontSize = max(12, chatFontSize - 1)
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                    }
                    .disabled(chatFontSize <= 12)
                    .help("Decrease Font Size")
                    Button {
                        chatFontSize = min(20, chatFontSize + 1)
                    } label: {
                        Image(systemName: "textformat.size.larger")
                    }
                    .disabled(chatFontSize >= 20)
                    .help("Increase Font Size")
                }
                .frame(width: 74)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16, alignment: .center)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Context loaded from: \(contextTitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(messages) { message in
                            HStack(alignment: .top) {
                                Text(message.role == "assistant" ? "AI" : "You")
                                    .font(.system(size: chatFontSize))
                                    .lineSpacing(5)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, message.role == "assistant" ? 0 : 8)
                                    .frame(width: 34, alignment: .leading)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(message.content)
                                        .font(.system(size: chatFontSize))
                                        .lineSpacing(5)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: message.role == "user" ? nil : .infinity, alignment: .leading)
                                    if message.role == "assistant", let tokenUsage = message.tokenUsage {
                                        Text(tokenUsage)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(message.role == "user" ? 8 : 0)
                                .background(
                                    message.role == "user"
                                        ? Color("BorderColor").opacity(0.5)
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .id(message.id)
                        }

                        if let errorText {
                            Text(errorText)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: messages.count) { _ in
                    if let lastID = messages.last?.id {
                        if shouldAnimateScroll {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        } else {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                chatInputField()

                Button("Send") {
                    sendMessage()
                }
                .disabled(isSending || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(12)
        }
        .frame(width: 720, height: 520)
        .onAppear {
            loadPersistedChat()
            prepareInitialContextIfNeeded()
            Task { @MainActor in
                shouldAnimateScroll = true
            }
        }
    }

    @ViewBuilder
    private func chatInputField() -> some View {
        if #available(macOS 13.0, *) {
            TextField("Ask about this article…", text: $inputText, axis: .vertical)
                .lineLimit(1 ... 6)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    sendMessage()
                }
                .disabled(isSending)
        } else {
            TextField("Ask about this article…", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    sendMessage()
                }
                .disabled(isSending)
        }
    }

    private func prepareInitialContextIfNeeded() {
        guard apiMessages.isEmpty else { return }
        let systemPrompt = "You are a useful research assistant. Return only essential information. No small talk, no preambles like \"here is\", and do not ask follow-up questions at the end."
        let articleContext = """
        You are helping with the following article.

        Title: \(article.title)

        Content:
        \(article.content)
        """
        apiMessages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": articleContext],
        ]
    }

    private var chatFileURL: URL? {
        if let myArticle = article as? MyArticleModel {
            return myArticle.path.deletingLastPathComponent().appendingPathComponent("\(myArticle.id.uuidString)-chats.json")
        }
        if let followingArticle = article as? FollowingArticleModel {
            return followingArticle.path.deletingLastPathComponent().appendingPathComponent("\(followingArticle.id.uuidString)-chats.json")
        }
        return nil
    }

    private func loadPersistedChat() {
        guard let chatFileURL else { return }
        guard let data = try? Data(contentsOf: chatFileURL) else { return }
        guard let persisted = try? JSONDecoder.shared.decode([ArticleAIChatPersistedMessage].self, from: data) else {
            return
        }

        messages = persisted.map { item in
            ArticleAIChatMessage(role: item.role, content: item.content, tokenUsage: item.tokenUsage)
        }
        let systemPrompt = "You are a useful research assistant. Return only essential information. No small talk, no preambles like \"here is\", and do not ask follow-up questions at the end."
        let articleContext = """
        You are helping with the following article.

        Title: \(article.title)

        Content:
        \(article.content)
        """
        apiMessages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": articleContext],
        ] + persisted.map { item in
            ["role": item.role, "content": item.content]
        }
    }

    private func persistChat() {
        guard let chatFileURL else { return }
        let persisted = messages.map { item in
            ArticleAIChatPersistedMessage(role: item.role, content: item.content, tokenUsage: item.tokenUsage)
        }
        guard let data = try? JSONEncoder.shared.encode(persisted) else { return }
        try? data.write(to: chatFileURL)
    }

    private var contextTitle: String {
        let title = article.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }

        let content = article.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            return "Untitled Article"
        }

        if let range = content.range(of: #"[.!?](\s|$)"#, options: .regularExpression) {
            let sentence = String(content[..<range.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                return sentence
            }
        }

        if let firstLine = content.split(whereSeparator: \.isNewline).first {
            let line = String(firstLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                return line
            }
        }

        return content
    }

    private func sendMessage() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        inputText = ""
        errorText = nil
        messages.append(ArticleAIChatMessage(role: "user", content: prompt, tokenUsage: nil))
        apiMessages.append(["role": "user", "content": prompt])
        persistChat()
        isSending = true

        Task {
            do {
                let (reply, tokenUsage) = try await requestReply(messages: apiMessages)
                await MainActor.run {
                    messages.append(ArticleAIChatMessage(role: "assistant", content: reply, tokenUsage: tokenUsage))
                    apiMessages.append(["role": "assistant", "content": reply])
                    persistChat()
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isSending = false
                }
            }
        }
    }

    private func requestReply(messages: [[String: String]]) async throws -> (String, String?) {
        let base = UserDefaults.standard.string(forKey: .settingsAIAPIBase)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model = UserDefaults.standard.string(forKey: .settingsAIPreferredModel) ?? "claude-sonnet-4-6"
        guard !base.isEmpty else {
            throw NSError(domain: "ArticleAIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI API base URL is not configured"])
        }
        guard let url = URL(string: base.hasSuffix("/") ? "\(base)chat/completions" : "\(base)/chat/completions") else {
            throw NSError(domain: "ArticleAIChat", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid AI API base URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = try? KeychainHelper.shared.loadValue(forKey: .settingsAIAPIToken), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let payload: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": messages.map { message in
                [
                    "role": message["role"] ?? "user",
                    "content": message["content"] ?? "",
                ]
            },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ArticleAIChat", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid AI API response"])
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ArticleAIChat", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "AI API error \(http.statusCode): \(body)"])
        }
        return try parseAssistantReply(data: data)
    }

    private func parseAssistantReply(data: Data) throws -> (String, String?) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any]
        else {
            throw NSError(domain: "ArticleAIChat", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unexpected AI response format"])
        }

        let tokenUsage: String? = {
            let modelName = json["model"] as? String
            guard let usage = json["usage"] as? [String: Any] else { return nil }
            let promptTokens = usage["prompt_tokens"] as? Int
            let completionTokens = usage["completion_tokens"] as? Int
            let totalTokens = usage["total_tokens"] as? Int
            var parts: [String] = [
                promptTokens != nil ? "Prompt: \(promptTokens!)" : nil,
                completionTokens != nil ? "Completion: \(completionTokens!)" : nil,
                totalTokens != nil ? "Total: \(totalTokens!)" : nil,
            ].compactMap { $0 }
            if let modelName, !modelName.isEmpty {
                parts.insert("Model: \(modelName)", at: 0)
            }
            guard !parts.isEmpty else { return nil }
            return parts.joined(separator: " • ")
        }()

        if let content = message["content"] as? String {
            return (content, tokenUsage)
        }
        if let contentParts = message["content"] as? [[String: Any]] {
            let text = contentParts
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                return (text, tokenUsage)
            }
        }
        throw NSError(domain: "ArticleAIChat", code: 5, userInfo: [NSLocalizedDescriptionKey: "AI response did not include content"])
    }
}
