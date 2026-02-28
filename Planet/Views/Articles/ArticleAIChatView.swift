//
//  ArticleAIChatView.swift
//  Planet
//
//  Created by Xin Liu on 2/23/26.
//

import Darwin
import Foundation
import SwiftUI

private struct ArticleAIChatMessage: Identifiable {
    let id: UUID
    let role: String
    let content: String
    let tokenUsage: String?

    init(id: UUID = UUID(), role: String, content: String, tokenUsage: String?) {
        self.id = id
        self.role = role
        self.content = content
        self.tokenUsage = tokenUsage
    }
}

struct ArticleAIChatPersistedMessage: Codable {
    let role: String
    let content: String
    let tokenUsage: String?
}

private struct ArticleAIToolCall {
    let id: String
    let name: String
    let arguments: Any
}

private enum ArticleAIToolResultMessageStyle {
    case openAI
    case anthropic
}

private struct ArticleAICompletionStep {
    let assistantMessage: [String: Any]
    let text: String
    let tokenUsage: String?
    let toolCalls: [ArticleAIToolCall]
    let toolResultStyle: ArticleAIToolResultMessageStyle
}

private struct ArticleAIReplyResult {
    let text: String
    let tokenUsage: String?
    let messages: [[String: Any]]
}

private struct ArticleAIStreamToolCallState {
    var id: String = ""
    var name: String = ""
    var arguments: String = ""
}

private struct ArticleAIToolFailureDetail {
    let toolName: String
    let toolCallID: String
    let error: String
    let argumentsPreview: String
    let resultPreview: String
}

private enum ArticleAIDebugLogger {
    private static let logURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("planet-ai-debug.log", isDirectory: false)
    private static let queue = DispatchQueue(label: "xyz.planetable.ArticleAIDebugLogger")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func log(_ message: String) {
        queue.async {
            let timestamp = formatter.string(from: Date())
            let line = "[\(timestamp)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }

            if !FileManager.default.fileExists(atPath: logURL.path) {
                _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }

            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        }
    }
}

struct ArticleAIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var article: ArticleModel

    @State private var messages: [ArticleAIChatMessage] = []
    @State private var apiMessages: [[String: Any]] = []
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var errorText: String? = nil
    @State private var shouldAnimateScroll: Bool = false
    @State private var chatFontSize: CGFloat = 14
    @State private var toolProgressText: String? = nil

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
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(messages) { message in
                            HStack(alignment: .top) {
                                Text(message.role == "assistant" ? "AI" : "You")
                                    .font(.system(size: chatFontSize))
                                    .lineSpacing(5)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, message.role == "assistant" ? 0 : 8)
                                    .frame(width: 34, alignment: .leading)
                                VStack(alignment: .leading, spacing: 6) {
                                    chatMessageContent(for: message)
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(message.id)
                        }

                        if isSending, let toolProgressText = toolProgressText {
                            HStack(alignment: .top) {
                                Text("AI")
                                    .font(.system(size: chatFontSize))
                                    .lineSpacing(5)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 34, alignment: .leading)
                                Text(toolProgressText)
                                    .font(.system(size: chatFontSize))
                                    .lineSpacing(5)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if let errorText = errorText {
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
            debugLog("---- AI chat opened ----")
            debugLog("contextTitle=\(contextTitle), articleType=\(String(describing: type(of: article))), articleID=\(article.id.uuidString)")
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
        apiMessages = [
            ["role": "system", "content": systemPrompt as Any],
            ["role": "user", "content": currentArticleContextMessage() as Any],
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
        guard let chatFileURL = chatFileURL else { return }
        guard let data = try? Data(contentsOf: chatFileURL) else { return }
        guard let persisted = try? JSONDecoder.shared.decode([ArticleAIChatPersistedMessage].self, from: data) else {
            return
        }

        messages = persisted.map { item in
            ArticleAIChatMessage(role: item.role, content: item.content, tokenUsage: item.tokenUsage)
        }
        let persistedAPIMessages: [[String: Any]] = persisted.map { item in
            [
                "role": item.role,
                "content": item.content,
            ]
        }
        apiMessages = [
            ["role": "system", "content": systemPrompt as Any],
            ["role": "user", "content": currentArticleContextMessage() as Any],
        ] + persistedAPIMessages
    }

    private func persistChat() {
        guard let chatFileURL = chatFileURL else { return }
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

    @ViewBuilder
    private func chatMessageContent(for message: ArticleAIChatMessage) -> some View {
        if message.role == "assistant",
            let attributed = attributedAssistantMessage(message.content)
        {
            Text(attributed)
        } else {
            Text(message.content)
        }
    }

    private func attributedAssistantMessage(_ content: String) -> AttributedString? {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return try? AttributedString(markdown: normalized, options: options)
    }

    private func sendMessage() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        debugLog("sendMessage promptLength=\(prompt.count), promptPreview=\(truncate(prompt, maxLength: 160))")
        inputText = ""
        errorText = nil
        messages.append(ArticleAIChatMessage(role: "user", content: prompt, tokenUsage: nil))
        apiMessages.append(["role": "user", "content": prompt])
        persistChat()
        isSending = true
        toolProgressText = nil
        let streamingMessageID = UUID()

        Task {
            do {
                let reply = try await requestReply(
                    messages: apiMessages,
                    onAssistantTextUpdate: { partialText in
                        await MainActor.run {
                            updateAssistantStreamingMessage(
                                id: streamingMessageID,
                                content: partialText,
                                tokenUsage: nil,
                                createIfMissing: true,
                                removeWhenEmpty: true
                            )
                        }
                    }
                )
                debugLog("assistant reply received textLength=\(reply.text.count), tokenUsage=\(reply.tokenUsage ?? "nil"), messagesCount=\(reply.messages.count)")
                await MainActor.run {
                    updateAssistantStreamingMessage(
                        id: streamingMessageID,
                        content: reply.text,
                        tokenUsage: reply.tokenUsage,
                        createIfMissing: true
                    )
                    apiMessages = reply.messages
                    persistChat()
                    toolProgressText = nil
                    isSending = false
                }
            } catch {
                debugLogError("sendMessage requestReply failed", error: error)
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == streamingMessageID }) {
                        let isEmpty = messages[index].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        if isEmpty {
                            messages.remove(at: index)
                        }
                    }
                    errorText = error.localizedDescription
                    toolProgressText = nil
                    isSending = false
                }
            }
        }
    }

    @MainActor
    private func updateAssistantStreamingMessage(
        id: UUID,
        content: String,
        tokenUsage: String?,
        createIfMissing: Bool = false,
        removeWhenEmpty: Bool = false
    ) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = messages.firstIndex(where: { $0.id == id }) {
            if removeWhenEmpty && trimmed.isEmpty {
                messages.remove(at: index)
                return
            }
            messages[index] = ArticleAIChatMessage(
                id: id,
                role: "assistant",
                content: content,
                tokenUsage: tokenUsage
            )
            return
        }

        guard createIfMissing, !trimmed.isEmpty else {
            return
        }
        messages.append(
            ArticleAIChatMessage(
                id: id,
                role: "assistant",
                content: content,
                tokenUsage: tokenUsage
            )
        )
    }

    private func requestReply(
        messages: [[String: Any]],
        onAssistantTextUpdate: ((String) async -> Void)? = nil
    ) async throws -> ArticleAIReplyResult {
        let base = UserDefaults.standard.string(forKey: .settingsAIAPIBase)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model = UserDefaults.standard.string(forKey: .settingsAIPreferredModel) ?? "claude-sonnet-4-6"

        guard !base.isEmpty else {
            throw NSError(domain: "ArticleAIChat", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI API base URL is not configured"])
        }
        guard let url = URL(string: base.hasSuffix("/") ? "\(base)chat/completions" : "\(base)/chat/completions") else {
            throw NSError(domain: "ArticleAIChat", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid AI API base URL"])
        }

        let token = try? KeychainHelper.shared.loadValue(forKey: .settingsAIAPIToken)
        let toolsEnabled = modelSupportsToolUse(model)
        debugLog("requestReply model=\(model), toolsEnabled=\(toolsEnabled), base=\(base), incomingMessages=\(messages.count), hasToken=\((token?.isEmpty == false))")

        var workingMessages = messages
        var finalTokenUsage: String? = nil
        var consecutiveToolFailureCount = 0
        var toolFailures: [ArticleAIToolFailureDetail] = []
        var mutationNotices: [String] = []
        var seenMutationNotices: Set<String> = []
        var totalToolCallsExecuted = 0
        var recentToolRuns: [String] = []
        var didUseToolsInResponse = false
        let maxToolSteps = 8
        for step in 0..<maxToolSteps {
            if didUseToolsInResponse {
                updateToolProgress(
                    thinkingProgressText(
                        round: step + 1,
                        maxRounds: maxToolSteps,
                        recentToolRuns: recentToolRuns
                    )
                )
            }
            debugLog("toolLoop step=\(step + 1)/\(maxToolSteps), workingMessages=\(workingMessages.count)")
            let completion = try await requestCompletion(
                url: url,
                model: model,
                token: token,
                messages: workingMessages,
                toolsEnabled: toolsEnabled,
                onTextDelta: onAssistantTextUpdate
            )
            finalTokenUsage = completion.tokenUsage
            workingMessages.append(completion.assistantMessage)
            debugLog("completion parsed step=\(step + 1), textLength=\(completion.text.count), toolCalls=\(completion.toolCalls.map { $0.name }.joined(separator: ",")), tokenUsage=\(completion.tokenUsage ?? "nil")")

            if completion.toolCalls.isEmpty {
                if didUseToolsInResponse {
                    updateToolProgress(
                        "Wrapping up the response...\nNo additional tool actions are needed."
                    )
                }
                let replyText = completion.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalText = assistantTextWithMutationNotices(
                    baseText: replyText,
                    mutationNotices: mutationNotices
                )
                guard !finalText.isEmpty else {
                    debugLog("completion has no tool calls and empty text")
                    throw NSError(domain: "ArticleAIChat", code: 6, userInfo: [NSLocalizedDescriptionKey: "AI response did not include content"])
                }
                if var last = workingMessages.last {
                    last["content"] = finalText
                    workingMessages[workingMessages.count - 1] = last
                }
                updateToolProgress(nil)
                return ArticleAIReplyResult(text: finalText, tokenUsage: finalTokenUsage, messages: workingMessages)
            }

            if let onAssistantTextUpdate {
                await onAssistantTextUpdate("")
            }

            didUseToolsInResponse = true
            updateToolProgress(
                toolQueueProgressText(
                    toolCalls: completion.toolCalls,
                    round: step + 1,
                    maxRounds: maxToolSteps
                )
            )

            for (toolIndex, toolCall) in completion.toolCalls.enumerated() {
                let arguments = decodeToolArguments(toolCall.arguments)
                updateToolProgress(
                    toolExecutionProgressText(
                        toolCall: toolCall,
                        arguments: arguments,
                        toolIndex: toolIndex,
                        totalTools: completion.toolCalls.count,
                        round: step + 1,
                        maxRounds: maxToolSteps
                    )
                )
                debugLog("executing tool name=\(toolCall.name), id=\(toolCall.id), args=\(debugDescription(arguments, maxLength: 1400))")
                let toolResult = await executeToolCall(toolCall)
                let toolSucceeded = toolResultSucceeded(toolResult)
                totalToolCallsExecuted += 1
                let completionTag: String = {
                    if let toolSucceeded {
                        return toolSucceeded ? "ok" : "failed"
                    } else {
                        return "done"
                    }
                }()
                recentToolRuns.append("\(friendlyToolLabel(for: toolCall.name)) [\(completionTag)]")
                if recentToolRuns.count > 3 {
                    recentToolRuns.removeFirst(recentToolRuns.count - 3)
                }
                updateToolProgress(
                    toolCompletionProgressText(
                        toolCall: toolCall,
                        toolResult: toolResult,
                        toolSucceeded: toolSucceeded,
                        toolIndex: toolIndex,
                        totalTools: completion.toolCalls.count,
                        round: step + 1,
                        totalExecuted: totalToolCallsExecuted
                    )
                )
                debugLog("tool result name=\(toolCall.name), id=\(toolCall.id), result=\(truncate(toolResult, maxLength: 2000))")
                if let mutationNotice = mutationNoticeFromToolResult(
                    toolName: toolCall.name,
                    toolResult: toolResult
                ), seenMutationNotices.insert(mutationNotice).inserted {
                    mutationNotices.append(mutationNotice)
                    debugLog("tracked mutation notice tool=\(toolCall.name), notice=\(mutationNotice)")
                }
                switch completion.toolResultStyle {
                case .openAI:
                    workingMessages.append([
                        "role": "tool",
                        "tool_call_id": toolCall.id,
                        "content": toolResult,
                    ])
                case .anthropic:
                    workingMessages.append([
                        "role": "user",
                        "content": [
                            [
                                "type": "tool_result",
                                "tool_use_id": toolCall.id,
                                "content": toolResult,
                            ],
                        ],
                    ])
                }
                refreshArticleContextAfterWriteIfNeeded(
                    toolName: toolCall.name,
                    toolResult: toolResult,
                    workingMessages: &workingMessages
                )

                if let localAssistantMessage = localAssistantMessageFromRejectedToolResult(toolResult) {
                    debugLog("tool requested local assistant rejection message tool=\(toolCall.name)")
                    let finalLocalMessage = assistantTextWithMutationNotices(
                        baseText: localAssistantMessage,
                        mutationNotices: mutationNotices
                    )
                    workingMessages.append([
                        "role": "assistant",
                        "content": finalLocalMessage,
                    ])
                    updateToolProgress(nil)
                    return ArticleAIReplyResult(
                        text: finalLocalMessage,
                        tokenUsage: finalTokenUsage,
                        messages: workingMessages
                    )
                }

                if let failure = toolFailureDetail(
                    toolResult: toolResult,
                    toolName: toolCall.name,
                    toolCallID: toolCall.id,
                    arguments: arguments
                ) {
                    consecutiveToolFailureCount += 1
                    toolFailures.append(failure)
                    debugLog("tool failure tracked count=\(consecutiveToolFailureCount), tool=\(failure.toolName), error=\(failure.error)")
                } else {
                    consecutiveToolFailureCount = 0
                }
            }

            if consecutiveToolFailureCount >= 3 {
                let failureMessage = buildToolFailureAssistantMessage(
                    model: model,
                    reason: "Tool calls failed \(consecutiveToolFailureCount) times in a row.",
                    failures: toolFailures
                )
                let finalFailureMessage = assistantTextWithMutationNotices(
                    baseText: failureMessage,
                    mutationNotices: mutationNotices
                )
                debugLog("aborting tool loop due to consecutive failures")
                workingMessages.append([
                    "role": "assistant",
                    "content": finalFailureMessage,
                ])
                updateToolProgress(nil)
                return ArticleAIReplyResult(
                    text: finalFailureMessage,
                    tokenUsage: finalTokenUsage,
                    messages: workingMessages
                )
            }
        }

        debugLog("tool loop limit reached: \(maxToolSteps), aborting to avoid infinite loop")
        let failureMessage = buildToolFailureAssistantMessage(
            model: model,
            reason: "Reached tool-call safety limit (\(maxToolSteps) rounds).",
            failures: toolFailures
        )
        let finalFailureMessage = assistantTextWithMutationNotices(
            baseText: failureMessage,
            mutationNotices: mutationNotices
        )
        workingMessages.append([
            "role": "assistant",
            "content": finalFailureMessage,
        ])
        updateToolProgress(nil)
        return ArticleAIReplyResult(
            text: finalFailureMessage,
            tokenUsage: finalTokenUsage,
            messages: workingMessages
        )
    }

    @MainActor
    private func updateToolProgress(_ text: String?) {
        toolProgressText = text
    }

    private func thinkingProgressText(round: Int, maxRounds: Int, recentToolRuns: [String]) -> String {
        let spinnerFrames = ["|", "/", "-", "\\"]
        let playfulMessages = [
            "reticulating splines",
            "untangling cosmic paperclips",
            "feeding bytes to tiny gremlins",
            "warming up the idea engine",
            "rehearsing dramatic keyboard clacks",
            "tuning the thought antenna",
        ]
        let spinner = spinnerFrames[(max(0, round - 1)) % spinnerFrames.count]
        let playful = playfulMessages.randomElement() ?? "warming up"

        var lines = [
            "[\(spinner)] \(playful)...",
            "Round \(round)/\(maxRounds)",
        ]
        if !recentToolRuns.isEmpty {
            lines.append("Ran: \(recentToolRuns.joined(separator: " -> "))")
        }
        return lines.joined(separator: "\n")
    }

    private func toolQueueProgressText(
        toolCalls: [ArticleAIToolCall],
        round: Int,
        maxRounds: Int
    ) -> String {
        let toolNames = toolCalls.map { friendlyToolLabel(for: $0.name) }
        let previewNames = Array(toolNames.prefix(3))
        let hiddenCount = max(0, toolNames.count - previewNames.count)
        var queueLine = "Round \(round)/\(maxRounds): tool queue ready with \(toolCalls.count) action(s)."
        if !previewNames.isEmpty {
            queueLine += "\nNext up: \(previewNames.joined(separator: " -> "))"
            if hiddenCount > 0 {
                queueLine += " (+\(hiddenCount) more)"
            }
        }
        return queueLine
    }

    private func toolExecutionProgressText(
        toolCall: ArticleAIToolCall,
        arguments: [String: Any],
        toolIndex: Int,
        totalTools: Int,
        round: Int,
        maxRounds: Int
    ) -> String {
        var lines: [String] = [
            "Round \(round)/\(maxRounds), action \(toolIndex + 1)/\(totalTools): \(friendlyToolLabel(for: toolCall.name))...",
        ]
        if let argumentSummary = summarizeToolArguments(
            toolName: toolCall.name,
            arguments: arguments
        ) {
            lines.append(argumentSummary)
        }
        return lines.joined(separator: "\n")
    }

    private func toolCompletionProgressText(
        toolCall: ArticleAIToolCall,
        toolResult: String,
        toolSucceeded: Bool?,
        toolIndex: Int,
        totalTools: Int,
        round: Int,
        totalExecuted: Int
    ) -> String {
        let statusText: String
        if let toolSucceeded {
            statusText = toolSucceeded ? "completed" : "hit a snag"
        } else {
            statusText = "returned data"
        }

        var lines: [String] = [
            "Round \(round), action \(toolIndex + 1)/\(totalTools): \(friendlyToolLabel(for: toolCall.name)) \(statusText).",
            "Tool actions finished so far: \(totalExecuted).",
        ]
        if let summary = summarizeToolResult(toolName: toolCall.name, toolResult: toolResult) {
            lines.append(summary)
        }
        if toolSucceeded == false {
            lines.append("Adjusting the plan and continuing...")
        }
        return lines.joined(separator: "\n")
    }

    private func friendlyToolLabel(for toolName: String) -> String {
        switch toolName {
        case "read_article":
            return "Reading article data"
        case "write_article":
            return "Applying article edits"
        case "read_planet":
            return "Reading planet settings"
        case "write_planet":
            return "Applying planet edits"
        case "shell":
            return "Running shell command"
        default:
            return "Running \(toolName)"
        }
    }

    private func summarizeToolArguments(
        toolName: String,
        arguments: [String: Any]
    ) -> String? {
        var parts: [String] = []

        switch toolName {
        case "read_article":
            if let articleID = stringValue(from: arguments["article_id"]) {
                parts.append("Target article: \(shortIdentifier(articleID)).")
            } else {
                parts.append("Target article: current selection.")
            }
            if let fields = stringArrayValue(from: arguments["fields"]), !fields.isEmpty {
                parts.append("Fields: \(previewList(fields, limit: 6)).")
            } else {
                parts.append("Fields: full snapshot.")
            }
        case "write_article":
            if let articleID = stringValue(from: arguments["article_id"]) {
                parts.append("Target article: \(shortIdentifier(articleID)).")
            } else {
                parts.append("Target article: current selection.")
            }
            let fields = inferredChangeKeys(
                from: arguments,
                idKeys: Set(["article_id", "replace_content"])
            )
            if !fields.isEmpty {
                parts.append("Planned updates: \(previewList(fields, limit: 6)).")
            }
            if boolValue(from: arguments["replace_content"]) == true {
                parts.append("Content mode: replace.")
            } else if fields.contains("content") {
                parts.append("Content mode: append.")
            }
        case "read_planet":
            if let planetID = stringValue(from: arguments["planet_id"]) {
                parts.append("Target planet: \(shortIdentifier(planetID)).")
            } else {
                parts.append("Target planet: current context.")
            }
            if let fields = stringArrayValue(from: arguments["fields"]), !fields.isEmpty {
                parts.append("Fields: \(previewList(fields, limit: 6)).")
            } else {
                parts.append("Fields: full snapshot.")
            }
        case "write_planet":
            if let planetID = stringValue(from: arguments["planet_id"]) {
                parts.append("Target planet: \(shortIdentifier(planetID)).")
            } else {
                parts.append("Target planet: current context.")
            }
            let fields = inferredChangeKeys(
                from: arguments,
                idKeys: Set(["planet_id"])
            )
            if !fields.isEmpty {
                parts.append("Planned updates: \(previewList(fields, limit: 6)).")
            }
        case "shell":
            if let command = stringValue(from: arguments["command"]) {
                let singleLine = command.replacingOccurrences(of: "\n", with: " ")
                parts.append("Command: \(truncateInline(singleLine, maxLength: 96)).")
            }
            if let workingDirectory = stringValue(from: arguments["working_directory"]) {
                parts.append("Dir: \(workingDirectory).")
            }
            if let timeout = intValue(from: arguments["timeout_seconds"]) {
                parts.append("Timeout: \(timeout)s.")
            }
        default:
            let keys = Array(arguments.keys).sorted()
            if !keys.isEmpty {
                parts.append("Argument keys: \(previewList(keys, limit: 6)).")
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func summarizeToolResult(toolName: String, toolResult: String) -> String? {
        guard
            let data = toolResult.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data),
            let payload = json as? [String: Any]
        else {
            return "Tool returned non-JSON output."
        }

        if (payload["ok"] as? Bool) == false {
            let error = stringValue(from: payload["error"]) ?? "Tool returned ok=false."
            let singleLineError = error.replacingOccurrences(of: "\n", with: " ")
            return "Issue: \(truncateInline(singleLineError, maxLength: 220))"
        }

        switch toolName {
        case "read_article":
            if let articlePayload = payload["article"] as? [String: Any] {
                return "Loaded article payload with \(articlePayload.keys.count) top-level field(s)."
            }
            return "Article payload loaded."
        case "write_article":
            let updatedFields = stringArrayValue(from: payload["updated_fields"]) ?? []
            if !updatedFields.isEmpty {
                return "Saved article fields: \(previewList(updatedFields, limit: 6))."
            }
            return "Article write completed."
        case "read_planet":
            if let planetPayload = payload["planet"] as? [String: Any] {
                return "Loaded planet payload with \(planetPayload.keys.count) top-level field(s)."
            }
            return "Planet payload loaded."
        case "write_planet":
            let updatedFields = stringArrayValue(from: payload["updated_fields"]) ?? []
            if !updatedFields.isEmpty {
                return "Saved planet fields: \(previewList(updatedFields, limit: 6))."
            }
            return "Planet write completed."
        case "shell":
            let exitCode = intValue(from: payload["exit_code"]) ?? 0
            let timedOut = (payload["timed_out"] as? Bool) ?? false
            if timedOut {
                return "Shell command timed out."
            }
            if exitCode != 0 {
                if let stderr = stringValue(from: payload["stderr"]), !stderr.isEmpty {
                    let singleLine = stderr.replacingOccurrences(of: "\n", with: " ")
                    return "Shell exit \(exitCode). stderr: \(truncateInline(singleLine, maxLength: 180))"
                }
                return "Shell exit \(exitCode)."
            }
            if let stdout = stringValue(from: payload["stdout"]),
                !stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                return "Shell finished with output."
            }
            return "Shell finished cleanly."
        default:
            return "Tool response received."
        }
    }

    private func inferredChangeKeys(
        from arguments: [String: Any],
        idKeys: Set<String>
    ) -> [String] {
        if let explicitChanges = dictionaryValue(from: arguments["changes"]) {
            return Array(explicitChanges.keys).sorted()
        }
        return arguments
            .keys
            .filter { $0 != "changes" && !idKeys.contains($0) }
            .sorted()
    }

    private func previewList(_ values: [String], limit: Int) -> String {
        let normalized = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !normalized.isEmpty else {
            return "-"
        }

        let preview = Array(normalized.prefix(limit))
        let hiddenCount = max(0, normalized.count - preview.count)
        var text = preview.joined(separator: ", ")
        if hiddenCount > 0 {
            text += ", +\(hiddenCount) more"
        }
        return text
    }

    private func shortIdentifier(_ value: String) -> String {
        guard value.count > 14 else {
            return value
        }
        return "\(value.prefix(8))...\(value.suffix(4))"
    }

    private func truncateInline(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else {
            return text
        }
        let index = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<index]) + "...[truncated]"
    }

    private func requestCompletion(
        url: URL,
        model: String,
        token: String?,
        messages: [[String: Any]],
        toolsEnabled: Bool,
        onTextDelta: ((String) async -> Void)? = nil
    ) async throws -> ArticleAICompletionStep {
        debugLog("requestCompletion start model=\(model), toolsEnabled=\(toolsEnabled), messages=\(messages.count)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let token = token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var payload: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": messages.map(messagePayload(from:)),
        ]
        let includeUsageOption = modelNeedsOpenAIStreamUsageOption(model)
        if includeUsageOption {
            payload["stream_options"] = [
                "include_usage": true,
            ]
        }
        if toolsEnabled {
            payload["tools"] = aiToolDefinitions
            payload["tool_choice"] = "auto"
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        debugLog("requestCompletion sending stream=true, includeUsageOption=\(includeUsageOption), payloadBytes=\(request.httpBody?.count ?? 0), accept=\(request.value(forHTTPHeaderField: "Accept") ?? "nil")")

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ArticleAIChat", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid AI API response"])
        }
        debugLog("requestCompletion status=\(http.statusCode), contentType=\(http.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
        guard (200 ... 299).contains(http.statusCode) else {
            let bodyData = try await dataFromAsyncBytes(bytes)
            let body = String(data: bodyData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ArticleAIChat", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "AI API error \(http.statusCode): \(body)"])
        }
        return try await parseCompletionStepFromStreamingBytes(
            bytes: bytes,
            fallbackModel: model,
            onTextDelta: onTextDelta
        )
    }

    private func parseCompletionStepFromStreamingBytes(
        bytes: URLSession.AsyncBytes,
        fallbackModel: String,
        onTextDelta: ((String) async -> Void)?
    ) async throws -> ArticleAICompletionStep {
        var rawLines: [String] = []
        var pendingEventDataLines: [String] = []
        var sawStreamPayload = false

        var streamedModel: String? = nil
        var streamedRole = "assistant"
        var streamedText = ""
        var streamedUsage: [String: Any]? = nil
        var openAIToolCallStates: [Int: ArticleAIStreamToolCallState] = [:]
        var anthropicToolOrder: [String] = []
        var anthropicToolNames: [String: String] = [:]
        var anthropicToolInputs: [String: Any] = [:]
        var streamEventCount = 0
        var parsedChunkCount = 0
        var failedChunkCount = 0
        var dataLineCount = 0
        var deltaCallbackCount = 0
        var ignoredChunkWithoutChoicesCount = 0

        debugLog("sse parser start fallbackModel=\(fallbackModel)")

        func parseChunkJSONObject(eventDataLines: [String], eventIndex: Int) -> [String: Any]? {
            let joinedWithNewline = eventDataLines.joined(separator: "\n")
            let joinedWithoutNewline = eventDataLines.joined()

            let candidate1 = joinedWithNewline.trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate2 = joinedWithoutNewline.trimmingCharacters(in: .whitespacesAndNewlines)
            var candidates: [String] = []
            if !candidate1.isEmpty {
                candidates.append(candidate1)
            }
            if !candidate2.isEmpty && candidate2 != candidate1 {
                candidates.append(candidate2)
            }

            guard !candidates.isEmpty else {
                debugLog("sse event \(eventIndex) has no JSON candidate after trimming")
                return nil
            }

            for (candidateIndex, candidate) in candidates.enumerated() {
                guard let data = candidate.data(using: .utf8) else {
                    debugLog("sse event \(eventIndex) candidate \(candidateIndex + 1) is not utf8 encodable")
                    continue
                }
                do {
                    let json = try JSONSerialization.jsonObject(with: data)
                    guard let object = json as? [String: Any] else {
                        debugLog("sse event \(eventIndex) candidate \(candidateIndex + 1) parsed non-object json type=\(debugValueType(json))")
                        continue
                    }
                    if candidateIndex > 0 {
                        debugLog("sse event \(eventIndex) recovered by candidate \(candidateIndex + 1)")
                    }
                    return object
                } catch {
                    let nsError = error as NSError
                    debugLog(
                        "sse event \(eventIndex) candidate \(candidateIndex + 1) parse error domain=\(nsError.domain), code=\(nsError.code), description=\(nsError.localizedDescription), preview=\(truncate(candidate, maxLength: 800))"
                    )
                }
            }

            return nil
        }

        func pendingEventLooksComplete(_ eventDataLines: [String]) -> Bool {
            guard !eventDataLines.isEmpty else {
                return false
            }

            let joinedWithNewline = eventDataLines.joined(separator: "\n")
            let joinedWithoutNewline = eventDataLines.joined()
            let candidate1 = joinedWithNewline.trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate2 = joinedWithoutNewline.trimmingCharacters(in: .whitespacesAndNewlines)
            var candidates: [String] = []
            if !candidate1.isEmpty {
                candidates.append(candidate1)
            }
            if !candidate2.isEmpty && candidate2 != candidate1 {
                candidates.append(candidate2)
            }

            for candidate in candidates {
                if candidate == "[DONE]" {
                    return true
                }
                guard let data = candidate.data(using: .utf8) else {
                    continue
                }
                if let json = try? JSONSerialization.jsonObject(with: data),
                    json is [String: Any]
                {
                    return true
                }
            }

            return false
        }

        func appendStreamedTextDelta(_ text: String, source: String) async {
            guard !text.isEmpty else {
                return
            }
            streamedText += text
            if let onTextDelta {
                await onTextDelta(streamedText)
                deltaCallbackCount += 1
                if deltaCallbackCount <= 3 || deltaCallbackCount % 25 == 0 {
                    debugLog(
                        "sse text update source=\(source), deltaLength=\(text.count), totalLength=\(streamedText.count), callbacks=\(deltaCallbackCount)"
                    )
                }
            }
        }

        func flushPendingEvent() async {
            guard !pendingEventDataLines.isEmpty else {
                return
            }

            let eventDataLines = pendingEventDataLines
            pendingEventDataLines.removeAll(keepingCapacity: true)
            streamEventCount += 1

            let joinedEventData = eventDataLines.joined(separator: "\n")
            let trimmedEventData = joinedEventData.trimmingCharacters(in: .whitespacesAndNewlines)
            if streamEventCount <= 5 || streamEventCount % 50 == 0 {
                debugLog(
                    "sse event \(streamEventCount) lineCount=\(eventDataLines.count), payloadLength=\(trimmedEventData.count), preview=\(truncate(trimmedEventData, maxLength: 220))"
                )
            }

            guard !trimmedEventData.isEmpty else {
                return
            }

            if trimmedEventData == "[DONE]" {
                debugLog("sse event \(streamEventCount) received done marker")
                return
            }

            guard let chunkJSON = parseChunkJSONObject(eventDataLines: eventDataLines, eventIndex: streamEventCount) else {
                failedChunkCount += 1
                return
            }
            parsedChunkCount += 1

            if let chunkModel = chunkJSON["model"] as? String, !chunkModel.isEmpty {
                streamedModel = chunkModel
            }
            if let usage = chunkJSON["usage"] as? [String: Any] {
                streamedUsage = usage
            }
            if let chunkError = chunkJSON["error"] {
                debugLog("sse chunk \(streamEventCount) reported error payload=\(debugDescription(chunkError, maxLength: 1200))")
            }

            if let eventType = chunkJSON["type"] as? String, !eventType.isEmpty {
                if streamEventCount <= 5 || eventType.contains("stop") || eventType.contains("error") {
                    debugLog("sse chunk \(streamEventCount) type=\(eventType)")
                }

                if eventType == "message_start",
                    let message = chunkJSON["message"] as? [String: Any]
                {
                    if let role = message["role"] as? String, !role.isEmpty {
                        streamedRole = role
                    }
                    if let model = message["model"] as? String, !model.isEmpty {
                        streamedModel = model
                    }
                } else if eventType == "content_block_delta",
                    let delta = chunkJSON["delta"] as? [String: Any],
                    let deltaType = delta["type"] as? String
                {
                    if deltaType == "text_delta",
                        let text = delta["text"] as? String
                    {
                        await appendStreamedTextDelta(text, source: "anthropic.text_delta")
                    } else if deltaType == "input_json_delta",
                        let partialJSON = delta["partial_json"] as? String,
                        !partialJSON.isEmpty
                    {
                        let blockIndex = intValue(from: chunkJSON["index"]) ?? 0
                        let toolID = "anthropic-tool-\(blockIndex)"
                        if !anthropicToolOrder.contains(toolID) {
                            anthropicToolOrder.append(toolID)
                        }
                        let previous = anthropicToolInputs[toolID] as? String ?? ""
                        anthropicToolInputs[toolID] = previous + partialJSON
                    }
                } else if eventType == "content_block_start",
                    let contentBlock = chunkJSON["content_block"] as? [String: Any],
                    (contentBlock["type"] as? String) == "tool_use"
                {
                    let blockIndex = intValue(from: chunkJSON["index"]) ?? 0
                    let toolID = (contentBlock["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        ?? "anthropic-tool-\(blockIndex)"
                    if !anthropicToolOrder.contains(toolID) {
                        anthropicToolOrder.append(toolID)
                    }
                    if let name = contentBlock["name"] as? String, !name.isEmpty {
                        anthropicToolNames[toolID] = name
                    }
                    if let input = contentBlock["input"] {
                        anthropicToolInputs[toolID] = input
                    }
                } else if eventType == "message_delta",
                    let usage = chunkJSON["usage"] as? [String: Any]
                {
                    streamedUsage = usage
                }
            }

            guard
                let choices = chunkJSON["choices"] as? [[String: Any]],
                let firstChoice = choices.first
            else {
                ignoredChunkWithoutChoicesCount += 1
                if ignoredChunkWithoutChoicesCount <= 5 || ignoredChunkWithoutChoicesCount % 25 == 0 {
                    debugLog("sse chunk \(streamEventCount) ignored (no choices). keys=\(Array(chunkJSON.keys).sorted())")
                }
                return
            }

            if let delta = firstChoice["delta"] as? [String: Any] {
                if let role = delta["role"] as? String, !role.isEmpty {
                    streamedRole = role
                }

                if let deltaContent = delta["content"] {
                    if let deltaText = deltaContent as? String {
                        await appendStreamedTextDelta(deltaText, source: "openai.content")
                    } else if let contentParts = deltaContent as? [[String: Any]] {
                        for part in contentParts {
                            if let text = part["text"] as? String {
                                await appendStreamedTextDelta(text, source: "openai.content.part")
                            }

                            guard (part["type"] as? String) == "tool_use" else {
                                continue
                            }
                            let partID = (part["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                            let toolID = (partID?.isEmpty == false) ? partID! : UUID().uuidString
                            if !anthropicToolOrder.contains(toolID) {
                                anthropicToolOrder.append(toolID)
                            }
                            if let name = part["name"] as? String, !name.isEmpty {
                                anthropicToolNames[toolID] = name
                            }
                            if let input = part["input"] {
                                anthropicToolInputs[toolID] = input
                            } else if let inputJSONDelta = part["input_json_delta"] as? String,
                                !inputJSONDelta.isEmpty
                            {
                                let previous = anthropicToolInputs[toolID] as? String ?? ""
                                anthropicToolInputs[toolID] = previous + inputJSONDelta
                            }
                        }
                    }
                }

                if let deltaToolCalls = delta["tool_calls"] as? [[String: Any]] {
                    for (fallbackIndex, deltaToolCall) in deltaToolCalls.enumerated() {
                        let index = intValue(from: deltaToolCall["index"]) ?? fallbackIndex
                        var state = openAIToolCallStates[index] ?? ArticleAIStreamToolCallState()

                        if let callID = deltaToolCall["id"] as? String, !callID.isEmpty {
                            state.id = callID
                        }
                        if let function = deltaToolCall["function"] as? [String: Any] {
                            if let namePart = function["name"] as? String, !namePart.isEmpty {
                                state.name += namePart
                            }
                            if let argumentsPart = function["arguments"] as? String, !argumentsPart.isEmpty {
                                state.arguments += argumentsPart
                            }
                        }

                        openAIToolCallStates[index] = state
                    }
                }
            } else if let message = firstChoice["message"] as? [String: Any] {
                if let role = message["role"] as? String, !role.isEmpty {
                    streamedRole = role
                }
                let messageText = extractText(from: message)
                if !messageText.isEmpty {
                    streamedText = messageText
                    if let onTextDelta {
                        await onTextDelta(streamedText)
                    }
                }
                if let toolCalls = message["tool_calls"] as? [[String: Any]] {
                    for (index, toolCall) in toolCalls.enumerated() {
                        guard let function = toolCall["function"] as? [String: Any] else { continue }
                        var state = openAIToolCallStates[index] ?? ArticleAIStreamToolCallState()
                        if let callID = toolCall["id"] as? String, !callID.isEmpty {
                            state.id = callID
                        }
                        if let name = function["name"] as? String, !name.isEmpty {
                            state.name = name
                        }
                        if let arguments = function["arguments"] as? String, !arguments.isEmpty {
                            state.arguments = arguments
                        }
                        openAIToolCallStates[index] = state
                    }
                }
            }
        }

        for try await line in bytes.lines {
            rawLines.append(line)

            if line.hasPrefix("data:") {
                sawStreamPayload = true
                dataLineCount += 1
                // Support both framing styles:
                // 1) spec-compliant SSE where a single event may contain multiple `data:` lines
                //    and ends with a blank line;
                // 2) one-JSON-per-`data:` line streams without blank-line separators.
                // Only flush early when the pending payload is already a complete event.
                if pendingEventLooksComplete(pendingEventDataLines) {
                    debugLog("sse flushing complete pending event before new data line \(dataLineCount)")
                    await flushPendingEvent()
                }
                var dataLine = String(line.dropFirst(5))
                if dataLine.hasPrefix(" ") {
                    dataLine.removeFirst()
                }
                pendingEventDataLines.append(dataLine)
                if dataLineCount <= 5 || dataLineCount % 100 == 0 {
                    debugLog("sse data line \(dataLineCount) length=\(dataLine.count), preview=\(truncate(dataLine, maxLength: 180))")
                }
                continue
            }

            if line.hasPrefix(":") || line.hasPrefix("event:") || line.hasPrefix("id:") || line.hasPrefix("retry:") {
                if rawLines.count <= 10 {
                    debugLog("sse control line preview=\(truncate(line, maxLength: 180))")
                }
                continue
            }

            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await flushPendingEvent()
                continue
            }

            if rawLines.count <= 10 || rawLines.count % 150 == 0 {
                debugLog("sse non-standard line preview=\(truncate(line, maxLength: 180))")
            }
        }

        await flushPendingEvent()
        debugLog("sse stream complete sawStreamPayload=\(sawStreamPayload), rawLines=\(rawLines.count), dataLines=\(dataLineCount), events=\(streamEventCount), parsedChunks=\(parsedChunkCount), failedChunks=\(failedChunkCount), textLength=\(streamedText.count)")

        if !sawStreamPayload {
            let rawBody = rawLines.joined(separator: "\n")
            debugLog("sse fallback to non-stream parse rawBodyLength=\(rawBody.count), preview=\(truncate(rawBody, maxLength: 1200))")
            guard let rawData = rawBody.data(using: .utf8) else {
                throw NSError(domain: "ArticleAIChat", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unexpected AI response format"])
            }
            do {
                return try parseCompletionStep(data: rawData)
            } catch {
                debugLogError("sse fallback parseCompletionStep failed", error: error)
                throw error
            }
        }

        let openAIToolCalls = openAIToolCallStates
            .sorted(by: { $0.key < $1.key })
            .compactMap { (_, state) -> [String: Any]? in
                let name = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    return nil
                }
                let callID = state.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? UUID().uuidString
                    : state.id
                let arguments = state.arguments.trimmingCharacters(in: .whitespacesAndNewlines)
                return [
                    "id": callID,
                    "type": "function",
                    "function": [
                        "name": name,
                        "arguments": arguments.isEmpty ? "{}" : arguments,
                    ],
                ]
            }

        var assistantMessage: [String: Any] = [
            "role": streamedRole,
        ]
        if !openAIToolCalls.isEmpty {
            assistantMessage["content"] = streamedText
            assistantMessage["tool_calls"] = openAIToolCalls
        } else if !anthropicToolOrder.isEmpty {
            var contentParts: [[String: Any]] = []
            if !streamedText.isEmpty {
                contentParts.append([
                    "type": "text",
                    "text": streamedText,
                ])
            }
            for toolID in anthropicToolOrder {
                guard let name = anthropicToolNames[toolID], !name.isEmpty else { continue }
                contentParts.append([
                    "type": "tool_use",
                    "id": toolID,
                    "name": name,
                    "input": anthropicToolInputs[toolID] ?? [:],
                ])
            }
            assistantMessage["content"] = contentParts
        } else {
            assistantMessage["content"] = streamedText
        }

        var reconstructedResponse: [String: Any] = [
            "choices": [
                [
                    "message": assistantMessage,
                ],
            ],
        ]
        if let usage = streamedUsage {
            reconstructedResponse["usage"] = usage
        }
        if let streamedModel = streamedModel, !streamedModel.isEmpty {
            reconstructedResponse["model"] = streamedModel
        } else if !fallbackModel.isEmpty {
            reconstructedResponse["model"] = fallbackModel
        }

        do {
            let reconstructedData = try JSONSerialization.data(withJSONObject: reconstructedResponse, options: [])
            let completion = try parseCompletionStep(data: reconstructedData)
            debugLog("requestCompletion stream done textLength=\(completion.text.count), toolCalls=\(completion.toolCalls.count), tokenUsage=\(completion.tokenUsage ?? "nil"), finalModel=\(streamedModel ?? fallbackModel)")
            return completion
        } catch {
            debugLogError("sse reconstructed response parsing failed", error: error)
            debugLog("sse reconstructed response preview=\(debugDescription(reconstructedResponse, maxLength: 1400))")
            throw error
        }
    }

    private func dataFromAsyncBytes(_ bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }

    private func parseCompletionStep(data: Data) throws -> ArticleAICompletionStep {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any]
        else {
            throw NSError(domain: "ArticleAIChat", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unexpected AI response format"])
        }

        let tokenUsage = formatTokenUsage(from: json)
        let text = extractText(from: message)

        var toolCalls: [ArticleAIToolCall] = []
        var toolResultStyle: ArticleAIToolResultMessageStyle = .openAI

        if let openAIToolCalls = message["tool_calls"] as? [[String: Any]], !openAIToolCalls.isEmpty {
            for call in openAIToolCalls {
                guard let function = call["function"] as? [String: Any],
                    let name = function["name"] as? String,
                    !name.isEmpty
                else {
                    continue
                }
                let callID = (call["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let arguments = function["arguments"] ?? "{}"
                toolCalls.append(
                    ArticleAIToolCall(
                        id: (callID?.isEmpty == false ? callID! : UUID().uuidString),
                        name: name,
                        arguments: arguments
                    )
                )
            }
        } else if let contentParts = message["content"] as? [[String: Any]] {
            let anthropicToolParts = contentParts.filter { ($0["type"] as? String) == "tool_use" }
            if !anthropicToolParts.isEmpty {
                toolResultStyle = .anthropic
                for part in anthropicToolParts {
                    guard let name = part["name"] as? String, !name.isEmpty else { continue }
                    let callID = (part["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let arguments = part["input"] ?? [:]
                    toolCalls.append(
                        ArticleAIToolCall(
                            id: (callID?.isEmpty == false ? callID! : UUID().uuidString),
                            name: name,
                            arguments: arguments
                        )
                    )
                }
            }
        }

        var assistantMessage = message
        assistantMessage["role"] = message["role"] as? String ?? "assistant"
        if assistantMessage["content"] == nil {
            assistantMessage["content"] = ""
        }

        debugLog("parseCompletionStep messageRole=\(assistantMessage["role"] as? String ?? "unknown"), textLength=\(text.count), toolCallCount=\(toolCalls.count), style=\(toolResultStyle == .openAI ? "openai" : "anthropic"), toolNames=\(toolCalls.map { $0.name }.joined(separator: ","))")

        return ArticleAICompletionStep(
            assistantMessage: assistantMessage,
            text: text,
            tokenUsage: tokenUsage,
            toolCalls: toolCalls,
            toolResultStyle: toolResultStyle
        )
    }

    private func formatTokenUsage(from json: [String: Any]) -> String? {
        let modelName = json["model"] as? String
        guard let usage = json["usage"] as? [String: Any] else { return nil }

        func usageInt(_ keys: [String]) -> Int? {
            for key in keys {
                if let value = usage[key] as? Int {
                    return value
                }
                if let number = usage[key] as? NSNumber {
                    return number.intValue
                }
            }
            return nil
        }

        let promptTokens = usageInt(["prompt_tokens", "input_tokens"])
        let completionTokens = usageInt(["completion_tokens", "output_tokens"])
        let explicitTotalTokens = usageInt(["total_tokens"])
        let totalTokens: Int? = explicitTotalTokens ?? {
            guard let promptTokens, let completionTokens else { return nil }
            return promptTokens + completionTokens
        }()
        let cacheReadTokens = usageInt(["cache_read_input_tokens", "prompt_cache_hit_tokens"])
        let cacheWriteTokens = usageInt(["cache_creation_input_tokens", "prompt_cache_miss_tokens"])

        var parts: [String] = [
            promptTokens != nil ? "Prompt: \(promptTokens!)" : nil,
            completionTokens != nil ? "Completion: \(completionTokens!)" : nil,
            totalTokens != nil ? "Total: \(totalTokens!)" : nil,
            cacheReadTokens != nil ? "Cache Read: \(cacheReadTokens!)" : nil,
            cacheWriteTokens != nil ? "Cache Write: \(cacheWriteTokens!)" : nil,
        ].compactMap { $0 }

        if let modelName = modelName, !modelName.isEmpty {
            parts.insert("Model: \(modelName)", at: 0)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func extractText(from message: [String: Any]) -> String {
        if let content = message["content"] as? String {
            return content
        }
        if let contentParts = message["content"] as? [[String: Any]] {
            return contentParts
                .compactMap { part in
                    if let text = part["text"] as? String {
                        return text
                    }
                    return nil
                }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private func messagePayload(from message: [String: Any]) -> [String: Any] {
        var payload: [String: Any] = [
            "role": (message["role"] as? String) ?? "user",
        ]
        if let content = message["content"] {
            payload["content"] = content
        } else {
            payload["content"] = ""
        }
        if let name = message["name"] as? String, !name.isEmpty {
            payload["name"] = name
        }
        if let toolCallID = message["tool_call_id"] as? String, !toolCallID.isEmpty {
            payload["tool_call_id"] = toolCallID
        }
        if let toolCalls = message["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
            payload["tool_calls"] = toolCalls
        }
        return payload
    }

    private func modelSupportsToolUse(_ model: String) -> Bool {
        let modelName = model.lowercased()
        return modelName.contains("sonnet") || modelName.contains("opus")
    }

    private func modelNeedsOpenAIStreamUsageOption(_ model: String) -> Bool {
        let normalized = model
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return false
        }

        // Anthropic-compatible models already emit usage in streaming events.
        if normalized.contains("claude")
            || normalized.contains("sonnet")
            || normalized.contains("opus")
            || normalized.contains("haiku")
        {
            return false
        }

        let candidate = normalized.split(separator: "/").last.map(String.init) ?? normalized
        if candidate.hasPrefix("gpt-")
            || candidate.hasPrefix("chatgpt")
            || candidate.hasPrefix("o1")
            || candidate.hasPrefix("o3")
            || candidate.hasPrefix("o4")
        {
            return true
        }
        if normalized.hasPrefix("openai/") || normalized.contains("/openai/") {
            return true
        }
        return false
    }

    private var aiToolDefinitions: [[String: Any]] {
        [
            [
                "type": "function",
                "function": [
                    "name": "read_article",
                    "description": "Read a MyArticleModel as JSON. Defaults to the currently opened article.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "article_id": [
                                "type": "string",
                                "description": "Optional UUID of the MyArticleModel to read.",
                            ],
                            "fields": [
                                "type": "array",
                                "items": [
                                    "type": "string",
                                ],
                                "description": "Optional subset of top-level JSON fields to return.",
                            ],
                        ],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "write_article",
                    "description": "Write changes into a MyArticleModel JSON and reload PlanetStore. For generated content, append by default; set replace_content=true only when the user explicitly asks to replace the full article body.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "article_id": [
                                "type": "string",
                                "description": "Optional UUID of the MyArticleModel to update.",
                            ],
                            "changes": [
                                "type": "object",
                                "description": "Top-level JSON fields to merge. Use null to clear optional values.",
                            ],
                            "replace_content": [
                                "type": "boolean",
                                "description": "Optional. Defaults to false. Set true only when user explicitly asks to replace the full article content.",
                            ],
                        ],
                        "required": ["changes"],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "read_planet",
                    "description": "Read a MyPlanetModel as JSON. Defaults to the current article's planet.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "planet_id": [
                                "type": "string",
                                "description": "Optional UUID of the MyPlanetModel to read.",
                            ],
                            "fields": [
                                "type": "array",
                                "items": [
                                    "type": "string",
                                ],
                                "description": "Optional subset of top-level JSON fields to return.",
                            ],
                        ],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "write_planet",
                    "description": "Write changes into a MyPlanetModel JSON and reload PlanetStore.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "planet_id": [
                                "type": "string",
                                "description": "Optional UUID of the MyPlanetModel to update.",
                            ],
                            "changes": [
                                "type": "object",
                                "description": "Top-level JSON fields to merge. Use null to clear optional values.",
                            ],
                        ],
                        "required": ["changes"],
                    ],
                ],
            ],
            [
                "type": "function",
                "function": [
                    "name": "shell",
                    "description": "Run a shell command in the Planet repo root (or a subdirectory).",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "command": [
                                "type": "string",
                                "description": "Shell command to execute.",
                            ],
                            "working_directory": [
                                "type": "string",
                                "description": "Optional relative path under Planet repo root. Defaults to repo root.",
                            ],
                            "timeout_seconds": [
                                "type": "integer",
                                "description": "Optional timeout in seconds. Default 15, max 120.",
                            ],
                        ],
                        "required": ["command"],
                    ],
                ],
            ],
        ]
    }

    private func executeToolCall(_ toolCall: ArticleAIToolCall) async -> String {
        let arguments = decodeToolArguments(toolCall.arguments)
        switch toolCall.name {
        case "read_article":
            return runReadArticleTool(arguments: arguments)
        case "write_article":
            return await runWriteArticleTool(arguments: arguments)
        case "read_planet":
            return runReadPlanetTool(arguments: arguments)
        case "write_planet":
            return runWritePlanetTool(arguments: arguments)
        case "shell":
            return runShellTool(arguments: arguments)
        default:
            debugLog("unknown tool requested: \(toolCall.name)")
            return toolResult([
                "ok": false,
                "error": "Unknown tool: \(toolCall.name)",
            ])
        }
    }

    private func decodeToolArguments(_ raw: Any) -> [String: Any] {
        if let dict = raw as? [String: Any] {
            return dict
        }
        if let text = raw as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return [:]
            }
            if let data = trimmed.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: data),
                let dict = json as? [String: Any]
            {
                return dict
            }
            debugLog("tool arguments were non-JSON string, using _raw fallback")
            return ["_raw": trimmed]
        }
        return [:]
    }

    @MainActor
    private func runReadArticleTool(arguments: [String: Any]) -> String {
        let articleID = stringValue(from: arguments["article_id"])
        debugLog("runReadArticleTool articleID=\(articleID ?? "nil"), fields=\(stringArrayValue(from: arguments["fields"]) ?? [])")
        guard let myArticle = resolveMyArticle(articleID: articleID) else {
            return toolResult([
                "ok": false,
                "error": articleID == nil
                    ? "No MyArticleModel is currently selected."
                    : "MyArticleModel not found for article_id: \(articleID!)",
            ])
        }

        do {
            let full = try encodeToDictionary(myArticle)
            let fields = stringArrayValue(from: arguments["fields"])
            let filtered = filter(dictionary: full, fields: fields)
            debugLog("runReadArticleTool success articleID=\(myArticle.id.uuidString), keys=\(filtered.keys.sorted())")
            return toolResult([
                "ok": true,
                "article_id": myArticle.id.uuidString,
                "planet_id": myArticle.planet.id.uuidString,
                "path": myArticle.path.path,
                "article": filtered,
            ])
        } catch {
            debugLogError("runReadArticleTool failed", error: error)
            return toolResult([
                "ok": false,
                "error": "Failed to encode article: \(error.localizedDescription)",
            ])
        }
    }

    @MainActor
    private func runWriteArticleTool(arguments: [String: Any]) async -> String {
        let articleID = stringValue(from: arguments["article_id"])
        let replaceContent = boolValue(from: arguments["replace_content"]) ?? false
        debugLog("runWriteArticleTool articleID=\(articleID ?? "nil"), replaceContent=\(replaceContent), rawChanges=\(debugDescription(arguments["changes"] ?? [:], maxLength: 1800))")
        guard let myArticle = resolveMyArticle(articleID: articleID) else {
            return toolResult([
                "ok": false,
                "error": articleID == nil
                    ? "No MyArticleModel is currently selected."
                    : "MyArticleModel not found for article_id: \(articleID!)",
                ])
        }
        guard var changes = normalizedChanges(from: arguments, idKeys: Set(["article_id", "replace_content"])) else {
            let rawChanges = arguments["changes"]
            let detail = "Expected `changes` as object/JSON-string, or top-level fields. got=\(debugValueType(rawChanges)); preview=\(debugDescription(rawChanges ?? "nil", maxLength: 500))"
            return rejectedChangesToolResult(
                toolName: "write_article",
                detail: detail,
                example: #"{"changes":{"content":"..."}}"#
            )
        }
        changes.removeValue(forKey: "id")
        if let invalidContentChangeDetail = normalizeArticleContentWriteChange(
            changes: &changes,
            article: myArticle,
            replaceContent: replaceContent
        ) {
            return rejectedChangesToolResult(
                toolName: "write_article",
                detail: invalidContentChangeDetail,
                example: #"{"changes":{"content":"..."},"replace_content":true}"#
            )
        }
        if changes.isEmpty {
            return rejectedChangesToolResult(
                toolName: "write_article",
                detail: "`changes` is empty.",
                example: #"{"changes":{"content":"..."}}"#
            )
        }
        debugLog("runWriteArticleTool normalized changeKeys=\(Array(changes.keys).sorted())")
        let shouldRegeneratePublicFiles = shouldRegenerateArticlePublicFiles(for: changes)

        do {
            var updated = try encodeToDictionary(myArticle)
            mergeJSON(base: &updated, changes: changes)
            updated["id"] = myArticle.id.uuidString
            let updatedData = try JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .sortedKeys])
            _ = try JSONDecoder.shared.decode(MyArticleModel.self, from: updatedData)
            try updatedData.write(to: myArticle.path, options: .atomic)

            try reloadStoreAndRestoreSelection(preferredArticleID: myArticle.id)
            let refreshed = resolveMyArticle(articleID: myArticle.id.uuidString) ?? myArticle
            var didSavePublic = false
            var didNotifyLoadArticle = false
            if shouldRegeneratePublicFiles {
                debugLog("runWriteArticleTool triggering savePublic for articleID=\(refreshed.id.uuidString)")
                try await runSavePublicForArticleOffMainActor(refreshed)
                didSavePublic = true
                NotificationCenter.default.post(name: .loadArticle, object: nil)
                didNotifyLoadArticle = true
                debugLog("runWriteArticleTool posted loadArticle notification articleID=\(refreshed.id.uuidString)")
            }
            let didSyncDraft = try syncDraftIfExists(for: refreshed)
            debugLog("runWriteArticleTool post-write hooks complete articleID=\(refreshed.id.uuidString), didSavePublic=\(didSavePublic), didNotifyLoadArticle=\(didNotifyLoadArticle), didSyncDraft=\(didSyncDraft)")
            let refreshedJSON = try encodeToDictionary(refreshed)
            debugLog("runWriteArticleTool success articleID=\(myArticle.id.uuidString), refreshedTitleLength=\(refreshed.title.count)")

            return toolResult([
                "ok": true,
                "article_id": myArticle.id.uuidString,
                "planet_id": refreshed.planet.id.uuidString,
                "path": refreshed.path.path,
                "updated_fields": Array(changes.keys).sorted(),
                "save_public_triggered": didSavePublic,
                "load_article_notified": didNotifyLoadArticle,
                "draft_synced": didSyncDraft,
                "article": refreshedJSON,
            ])
        } catch {
            debugLogError("runWriteArticleTool failed", error: error)
            return toolResult([
                "ok": false,
                "error": "Failed to write article: \(error.localizedDescription)",
            ])
        }
    }

    private func runSavePublicForArticleOffMainActor(_ article: MyArticleModel) async throws {
        let articleBox = UncheckedSendableBox(article)
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try articleBox.value.savePublic()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private final class UncheckedSendableBox<Value>: @unchecked Sendable {
        let value: Value
        init(_ value: Value) {
            self.value = value
        }
    }

    @MainActor
    private func runReadPlanetTool(arguments: [String: Any]) -> String {
        let planetID = stringValue(from: arguments["planet_id"])
        debugLog("runReadPlanetTool planetID=\(planetID ?? "nil"), fields=\(stringArrayValue(from: arguments["fields"]) ?? [])")
        guard let planet = resolveMyPlanet(planetID: planetID) else {
            return toolResult([
                "ok": false,
                "error": planetID == nil
                    ? "No MyPlanetModel is available for current context."
                    : "MyPlanetModel not found for planet_id: \(planetID!)",
            ])
        }

        do {
            let full = try encodeToDictionary(planet)
            let fields = stringArrayValue(from: arguments["fields"])
            let filtered = filter(dictionary: full, fields: fields)
            debugLog("runReadPlanetTool success planetID=\(planet.id.uuidString), keys=\(filtered.keys.sorted())")
            return toolResult([
                "ok": true,
                "planet_id": planet.id.uuidString,
                "path": planet.infoPath.path,
                "planet": filtered,
            ])
        } catch {
            debugLogError("runReadPlanetTool failed", error: error)
            return toolResult([
                "ok": false,
                "error": "Failed to encode planet: \(error.localizedDescription)",
            ])
        }
    }

    @MainActor
    private func runWritePlanetTool(arguments: [String: Any]) -> String {
        let planetID = stringValue(from: arguments["planet_id"])
        debugLog("runWritePlanetTool planetID=\(planetID ?? "nil"), rawChanges=\(debugDescription(arguments["changes"] ?? [:], maxLength: 1800))")
        guard let planet = resolveMyPlanet(planetID: planetID) else {
            return toolResult([
                "ok": false,
                "error": planetID == nil
                    ? "No MyPlanetModel is available for current context."
                    : "MyPlanetModel not found for planet_id: \(planetID!)",
                ])
        }
        guard var changes = normalizedChanges(from: arguments, idKeys: Set(["planet_id"])) else {
            let rawChanges = arguments["changes"]
            let detail = "Expected `changes` as object/JSON-string, or top-level fields. got=\(debugValueType(rawChanges)); preview=\(debugDescription(rawChanges ?? "nil", maxLength: 500))"
            return rejectedChangesToolResult(
                toolName: "write_planet",
                detail: detail,
                example: #"{"changes":{"name":"..."}}"#
            )
        }
        changes.removeValue(forKey: "id")
        if changes.isEmpty {
            return rejectedChangesToolResult(
                toolName: "write_planet",
                detail: "`changes` is empty.",
                example: #"{"changes":{"name":"..."}}"#
            )
        }
        debugLog("runWritePlanetTool normalized changeKeys=\(Array(changes.keys).sorted())")

        let selectedArticleID = PlanetStore.shared.selectedArticle?.id

        do {
            var updated = try encodeToDictionary(planet)
            mergeJSON(base: &updated, changes: changes)
            updated["id"] = planet.id.uuidString
            let updatedData = try JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .sortedKeys])
            _ = try JSONDecoder.shared.decode(MyPlanetModel.self, from: updatedData)
            try updatedData.write(to: planet.infoPath, options: .atomic)

            try reloadStoreAndRestoreSelection(preferredArticleID: selectedArticleID)
            let refreshed = resolveMyPlanet(planetID: planet.id.uuidString) ?? planet
            let refreshedJSON = try encodeToDictionary(refreshed)
            debugLog("runWritePlanetTool success planetID=\(planet.id.uuidString), refreshedName=\(refreshed.name)")

            return toolResult([
                "ok": true,
                "planet_id": refreshed.id.uuidString,
                "path": refreshed.infoPath.path,
                "updated_fields": Array(changes.keys).sorted(),
                "planet": refreshedJSON,
            ])
        } catch {
            debugLogError("runWritePlanetTool failed", error: error)
            return toolResult([
                "ok": false,
                "error": "Failed to write planet: \(error.localizedDescription)",
            ])
        }
    }

    private func runShellTool(arguments: [String: Any]) -> String {
        guard let command = stringValue(from: arguments["command"]) else {
            return toolResult([
                "ok": false,
                "error": "Missing required `command`.",
            ])
        }

        let timeout = max(1, min(120, intValue(from: arguments["timeout_seconds"]) ?? 15))
        let repoRoot = URLUtils.repoPath().standardizedFileURL
        let workingDirectoryInput = stringValue(from: arguments["working_directory"])
        debugLog("runShellTool command=\(command), workingDirectoryInput=\(workingDirectoryInput ?? "nil"), timeout=\(timeout)")

        let resolvedWorkingDirectory: URL
        switch resolveShellWorkingDirectory(input: workingDirectoryInput, repoRoot: repoRoot) {
        case .success(let url):
            resolvedWorkingDirectory = url
        case .failure(let error):
            debugLog("runShellTool invalid working directory: \(error.localizedDescription)")
            return toolResult([
                "ok": false,
                "error": error.localizedDescription,
            ])
        }

        do {
            let shellResult = try runShellCommand(
                command,
                workingDirectory: resolvedWorkingDirectory,
                timeoutSeconds: timeout
            )
            debugLog("runShellTool completed exitCode=\(shellResult.exitCode), timedOut=\(shellResult.timedOut), stdoutLength=\(shellResult.stdout.count), stderrLength=\(shellResult.stderr.count)")
            return toolResult([
                "ok": shellResult.exitCode == 0 && shellResult.timedOut == false,
                "command": command,
                "working_directory": resolvedWorkingDirectory.path,
                "exit_code": shellResult.exitCode,
                "timed_out": shellResult.timedOut,
                "stdout": truncate(shellResult.stdout, maxLength: 12000),
                "stderr": truncate(shellResult.stderr, maxLength: 12000),
            ])
        } catch {
            debugLogError("runShellTool failed", error: error)
            return toolResult([
                "ok": false,
                "error": "Shell execution failed: \(error.localizedDescription)",
            ])
        }
    }

    @MainActor
    private func resolveMyArticle(articleID: String?) -> MyArticleModel? {
        if let articleID = articleID {
            guard let articleUUID = UUID(uuidString: articleID) else {
                return nil
            }
            for planet in PlanetStore.shared.myPlanets {
                if let found = (planet.articles ?? []).first(where: { $0.id == articleUUID }) {
                    return found
                }
            }
            return nil
        }

        if let myArticle = article as? MyArticleModel {
            return myArticle
        }
        if let selectedMyArticle = PlanetStore.shared.selectedArticle as? MyArticleModel {
            return selectedMyArticle
        }
        return nil
    }

    @MainActor
    private func resolveMyPlanet(planetID: String?) -> MyPlanetModel? {
        if let planetID = planetID {
            guard let planetUUID = UUID(uuidString: planetID) else {
                return nil
            }
            return PlanetStore.shared.myPlanets.first(where: { $0.id == planetUUID })
        }

        if let myArticle = article as? MyArticleModel {
            return PlanetStore.shared.myPlanets.first(where: { $0.id == myArticle.planet.id }) ?? myArticle.planet
        }
        if let selectedMyArticle = PlanetStore.shared.selectedArticle as? MyArticleModel {
            return PlanetStore.shared.myPlanets.first(where: { $0.id == selectedMyArticle.planet.id }) ?? selectedMyArticle.planet
        }
        if case .myPlanet(let selectedPlanet)? = PlanetStore.shared.selectedView {
            return PlanetStore.shared.myPlanets.first(where: { $0.id == selectedPlanet.id }) ?? selectedPlanet
        }
        return PlanetStore.shared.myPlanets.first
    }

    @MainActor
    private func reloadStoreAndRestoreSelection(preferredArticleID: UUID?) throws {
        let selectedViewSnapshot = PlanetStore.shared.selectedView
        debugLog("reloadStoreAndRestoreSelection start preferredArticleID=\(preferredArticleID?.uuidString ?? "nil"), selectedView=\(String(describing: selectedViewSnapshot))")
        try PlanetStore.shared.load()

        if let selectedViewSnapshot = selectedViewSnapshot {
            switch selectedViewSnapshot {
            case .today:
                PlanetStore.shared.selectedView = .today
            case .unread:
                PlanetStore.shared.selectedView = .unread
            case .starred:
                PlanetStore.shared.selectedView = .starred
            case .myPlanet(let planet):
                if let refreshed = PlanetStore.shared.myPlanets.first(where: { $0.id == planet.id }) {
                    PlanetStore.shared.selectedView = .myPlanet(refreshed)
                } else {
                    PlanetStore.shared.selectedView = nil
                }
            case .followingPlanet(let planet):
                if let refreshed = PlanetStore.shared.followingPlanets.first(where: { $0.id == planet.id }) {
                    PlanetStore.shared.selectedView = .followingPlanet(refreshed)
                } else {
                    PlanetStore.shared.selectedView = nil
                }
            }
        } else {
            PlanetStore.shared.selectedView = nil
        }

        PlanetStore.shared.refreshSelectedArticles()
        if let preferredArticleID = preferredArticleID {
            selectArticle(withID: preferredArticleID)
        }
        debugLog("reloadStoreAndRestoreSelection done selectedView=\(String(describing: PlanetStore.shared.selectedView)), selectedArticle=\(PlanetStore.shared.selectedArticle?.id.uuidString ?? "nil")")
    }

    @MainActor
    private func selectArticle(withID articleID: UUID) {
        if let selected = PlanetStore.shared.selectedArticleList?.first(where: { $0.id == articleID }) {
            PlanetStore.shared.selectedArticle = selected
            return
        }
        for planet in PlanetStore.shared.myPlanets {
            if let myArticle = (planet.articles ?? []).first(where: { $0.id == articleID }) {
                PlanetStore.shared.selectedArticle = myArticle
                return
            }
        }
    }

    private func encodeToDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder.shared.encode(value)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any] else {
            throw NSError(domain: "ArticleAIChat", code: 8, userInfo: [NSLocalizedDescriptionKey: "Model JSON is not an object"])
        }
        return dict
    }

    private func normalizeArticleContentWriteChange(
        changes: inout [String: Any],
        article: MyArticleModel,
        replaceContent: Bool
    ) -> String? {
        guard let rawContent = changes["content"] else {
            return nil
        }

        if rawContent is NSNull {
            return replaceContent
                ? nil
                : "`changes.content` clears the full article body. Set `replace_content` to true only if the user explicitly requested full overwrite."
        }

        guard let contentText = rawContent as? String else {
            return "`changes.content` must be a string."
        }

        var normalizedNewContent = contentText
        if let extractedHeading = extractLeadingMarkdownH1(from: contentText) {
            normalizedNewContent = extractedHeading.content
            changes["title"] = extractedHeading.title
        }

        if replaceContent {
            changes["content"] = normalizedNewContent
            return nil
        }

        changes["content"] = appendedArticleContent(
            existingContent: article.content,
            newContent: normalizedNewContent
        )
        return nil
    }

    private func extractLeadingMarkdownH1(from content: String) -> (title: String, content: String)? {
        let normalizedContent = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines = normalizedContent.components(separatedBy: "\n")

        guard let headingIndex = lines.firstIndex(where: {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            return nil
        }

        let line = lines[headingIndex].trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("#"), !line.hasPrefix("##") else {
            return nil
        }

        let remainder = line.dropFirst()
        guard let first = remainder.first, first == " " || first == "\t" else {
            return nil
        }

        var title = String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.replacingOccurrences(of: #"\s#+\s*$"#, with: "", options: .regularExpression)
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return nil
        }

        lines.remove(at: headingIndex)
        if headingIndex < lines.count,
            lines[headingIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            lines.remove(at: headingIndex)
        }

        let strippedContent = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (title: title, content: strippedContent)
    }

    private func appendedArticleContent(existingContent: String, newContent: String) -> String {
        let trimmedNewContent = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNewContent.isEmpty else {
            return existingContent
        }

        guard !existingContent.isEmpty else {
            return trimmedNewContent
        }
        return "\(existingContent)\n\n---\n\n\(trimmedNewContent)"
    }

    private func shouldRegenerateArticlePublicFiles(for changes: [String: Any]) -> Bool {
        changes.keys.contains("title") || changes.keys.contains("content")
    }

    @MainActor
    private func syncDraftIfExists(for article: MyArticleModel) throws -> Bool {
        let draftDirectoryPath = article.planet.articleDraftsPath.appendingPathComponent(
            article.id.uuidString,
            isDirectory: true
        )
        let draftInfoPath = draftDirectoryPath.appendingPathComponent("Draft.json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: draftInfoPath.path) else {
            debugLog("syncDraftIfExists no draft file for articleID=\(article.id.uuidString)")
            return false
        }

        let draft: DraftModel
        if let existing = article.draft {
            draft = existing
        } else {
            draft = try DraftModel.load(from: draftDirectoryPath, article: article)
            article.draft = draft
        }

        draft.date = article.created
        draft.title = article.title
        draft.content = article.content
        draft.heroImage = article.heroImage
        draft.externalLink = article.externalLink ?? ""
        draft.tags = article.tags ?? [:]
        syncDraftAttachments(from: article, draft: draft)
        try draft.save()
        return true
    }

    private func syncDraftAttachments(from article: MyArticleModel, draft: DraftModel) {
        var existingByName: [String: Attachment] = [:]
        for attachment in draft.attachments {
            existingByName[attachment.name] = attachment
        }
        let articleAttachmentNames = article.attachments ?? []
        draft.attachments = articleAttachmentNames.map { name in
            if let existing = existingByName[name] {
                existing.draft = draft
                return existing
            }
            let articleAttachmentPath = article.publicBasePath.appendingPathComponent(name, isDirectory: false)
            let attachment = Attachment(name: name, type: AttachmentType.from(articleAttachmentPath))
            attachment.draft = draft
            return attachment
        }
    }

    private func mergeJSON(base: inout [String: Any], changes: [String: Any]) {
        for (key, value) in changes {
            if var nestedBase = base[key] as? [String: Any],
                let nestedChanges = value as? [String: Any]
            {
                mergeJSON(base: &nestedBase, changes: nestedChanges)
                base[key] = nestedBase
            } else {
                base[key] = value
            }
        }
    }

    private func filter(dictionary: [String: Any], fields: [String]?) -> [String: Any] {
        guard let fields = fields, !fields.isEmpty else {
            return dictionary
        }
        var filtered: [String: Any] = [:]
        for field in fields {
            if let value = dictionary[field] {
                filtered[field] = value
            }
        }
        return filtered
    }

    private func dictionaryValue(from value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] {
            return dict
        }
        if let dict = value as? [AnyHashable: Any] {
            var normalized: [String: Any] = [:]
            for (key, item) in dict {
                if let keyString = key as? String {
                    normalized[keyString] = item
                }
            }
            if !normalized.isEmpty {
                return normalized
            }
        }
        if let text = value as? String {
            return decodeJSONObject(fromText: text)
        }
        return nil
    }

    private func normalizedChanges(from arguments: [String: Any], idKeys: Set<String>) -> [String: Any]? {
        let hasExplicitChanges = arguments.keys.contains("changes")
        if hasExplicitChanges {
            if let explicit = dictionaryValue(from: arguments["changes"]) {
                return explicit
            }
            debugLog("normalizedChanges could not parse explicit changes payload; attempting top-level fallback")
        }

        var inferred: [String: Any] = [:]
        for (key, value) in arguments {
            if key == "changes" || idKeys.contains(key) {
                continue
            }
            inferred[key] = value
        }
        if !inferred.isEmpty {
            debugLog("normalizedChanges inferred from top-level keys=\(Array(inferred.keys).sorted())")
            return inferred
        }
        return nil
    }

    private func debugValueType(_ value: Any?) -> String {
        guard let value else {
            return "nil"
        }
        return String(reflecting: type(of: value))
    }

    private func decodeJSONObject(fromText text: String) -> [String: Any]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let unfenced = stripCodeFenceIfNeeded(trimmed)
        var candidates: [String] = [unfenced]

        let newlineEscaped = escapeRawControlCharactersInsideJSONString(unfenced)
        if newlineEscaped != unfenced {
            candidates.append(newlineEscaped)
        }

        for candidate in candidates {
            if let dict = parseJSONObject(fromText: candidate) {
                return dict
            }
            if let wrapped = parseJSONStringLiteral(fromText: candidate),
                let dict = parseJSONObject(fromText: wrapped)
            {
                return dict
            }
            if let wrapped = parseJSONStringLiteral(fromText: candidate) {
                if let singleField = parseSingleFieldObjectString(wrapped) {
                    debugLog("decodeJSONObject salvaged malformed wrapped object keys=\(Array(singleField.keys).sorted())")
                    return singleField
                }
                let wrappedEscaped = escapeRawControlCharactersInsideJSONString(wrapped)
                if let dict = parseJSONObject(fromText: wrappedEscaped) {
                    return dict
                }
                if let singleField = parseSingleFieldObjectString(wrappedEscaped) {
                    debugLog("decodeJSONObject salvaged malformed wrapped+escaped object keys=\(Array(singleField.keys).sorted())")
                    return singleField
                }
            }
            if let singleField = parseSingleFieldObjectString(candidate) {
                debugLog("decodeJSONObject salvaged malformed object keys=\(Array(singleField.keys).sorted())")
                return singleField
            }
        }

        return nil
    }

    private func parseJSONObject(fromText text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data),
            let dict = json as? [String: Any]
        else {
            return nil
        }
        return dict
    }

    private func parseJSONStringLiteral(fromText text: String) -> String? {
        guard let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data),
            let wrapped = json as? String
        else {
            return nil
        }
        return wrapped
    }

    private func parseSingleFieldObjectString(_ text: String) -> [String: Any]? {
        // Keep this fallback strict: only salvage an actual single-field object with
        // a JSON-style escaped string value. This prevents trailing sibling fields
        // from being absorbed into the first value when model output is malformed.
        let pattern = #"^\{\s*"([^"\\]+)"\s*:\s*"((?:[^"\\]|\\.)*)"\s*\}\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let nsText = text as NSString
        let searchRange = NSRange(location: 0, length: nsText.length)
        guard
            let match = regex.firstMatch(in: text, options: [], range: searchRange),
            match.numberOfRanges == 3,
            match.range(at: 1).location != NSNotFound,
            match.range(at: 2).location != NSNotFound
        else {
            return nil
        }

        let key = nsText.substring(with: match.range(at: 1))
        let rawValue = nsText.substring(with: match.range(at: 2))
        let normalizedValue = unescapeJSONStringLikeValue(rawValue)
        return [key: normalizedValue]
    }

    private func unescapeJSONStringLikeValue(_ raw: String) -> String {
        let characters = Array(raw)
        var output = ""
        output.reserveCapacity(raw.count)

        var index = 0
        while index < characters.count {
            let character = characters[index]
            guard character == "\\" else {
                output.append(character)
                index += 1
                continue
            }

            index += 1
            guard index < characters.count else {
                output.append("\\")
                break
            }

            let escape = characters[index]
            switch escape {
            case "\"":
                output.append("\"")
            case "\\":
                output.append("\\")
            case "/":
                output.append("/")
            case "b":
                output.append("\u{08}")
            case "f":
                output.append("\u{0C}")
            case "n":
                output.append("\n")
            case "r":
                output.append("\r")
            case "t":
                output.append("\t")
            case "u":
                if index + 4 < characters.count {
                    let hex = String(characters[(index + 1)...(index + 4)])
                    if let scalarValue = UInt32(hex, radix: 16),
                        let scalar = UnicodeScalar(scalarValue)
                    {
                        output.unicodeScalars.append(scalar)
                        index += 4
                    } else {
                        output.append("\\u")
                    }
                } else {
                    output.append("\\u")
                }
            default:
                output.append(escape)
            }
            index += 1
        }

        return output
    }

    private func stripCodeFenceIfNeeded(_ text: String) -> String {
        guard text.hasPrefix("```"),
            let firstNewline = text.range(of: "\n"),
            let lastFence = text.range(of: "```", options: .backwards),
            firstNewline.upperBound <= lastFence.lowerBound
        else {
            return text
        }
        let inner = String(text[firstNewline.upperBound..<lastFence.lowerBound])
        return inner.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func escapeRawControlCharactersInsideJSONString(_ text: String) -> String {
        struct JSONContainerState {
            enum Kind {
                case object
                case array
            }

            var kind: Kind
            var expectingObjectKey: Bool
        }

        let input = Array(text)
        var output = ""
        output.reserveCapacity(text.count + 32)
        var containerStack: [JSONContainerState] = []
        var isInsideString = false
        var currentStringIsObjectKey = false
        var isEscaping = false

        for index in input.indices {
            let char = input[index]
            if isEscaping {
                output.append(char)
                isEscaping = false
                continue
            }
            if char == "\\" {
                output.append(char)
                isEscaping = true
                continue
            }
            if char == "\"" {
                if isInsideString {
                    let next = nextNonWhitespaceCharacter(in: input, after: index)
                    let canCloseOnColon = currentStringIsObjectKey
                    let shouldClose: Bool = {
                        guard let next else {
                            return true
                        }
                        if next == "," || next == "}" || next == "]" {
                            return true
                        }
                        if canCloseOnColon && next == ":" {
                            return true
                        }
                        return false
                    }()

                    if shouldClose {
                        output.append(char)
                        isInsideString = false
                        currentStringIsObjectKey = false
                    } else {
                        // Salvage malformed JSON where inner string quotes were not escaped.
                        output.append("\\\"")
                    }
                } else {
                    output.append(char)
                    isInsideString = true
                    currentStringIsObjectKey = {
                        guard let top = containerStack.last else {
                            return false
                        }
                        return top.kind == .object && top.expectingObjectKey
                    }()
                }
                continue
            }
            if isInsideString {
                switch char {
                case "\n":
                    output.append("\\n")
                    continue
                case "\r":
                    output.append("\\r")
                    continue
                case "\t":
                    output.append("\\t")
                    continue
                default:
                    break
                }
            }

            if !isInsideString {
                switch char {
                case "{":
                    containerStack.append(JSONContainerState(kind: .object, expectingObjectKey: true))
                case "[":
                    containerStack.append(JSONContainerState(kind: .array, expectingObjectKey: false))
                case "}":
                    if !containerStack.isEmpty {
                        containerStack.removeLast()
                    }
                case "]":
                    if !containerStack.isEmpty {
                        containerStack.removeLast()
                    }
                case ":":
                    if var top = containerStack.last, top.kind == .object {
                        top.expectingObjectKey = false
                        containerStack[containerStack.count - 1] = top
                    }
                case ",":
                    if var top = containerStack.last, top.kind == .object {
                        top.expectingObjectKey = true
                        containerStack[containerStack.count - 1] = top
                    }
                default:
                    break
                }
            }
            output.append(char)
        }
        return output
    }

    private func nextNonWhitespaceCharacter(in text: [Character], after index: Int) -> Character? {
        var cursor = text.index(after: index)
        while cursor < text.endIndex {
            let char = text[cursor]
            switch char {
            case " ", "\n", "\r", "\t":
                cursor = text.index(after: cursor)
            default:
                return char
            }
        }
        return nil
    }

    private func stringArrayValue(from value: Any?) -> [String]? {
        if let array = value as? [String] {
            return array
        }
        if let array = value as? [Any] {
            let strings = array.compactMap { $0 as? String }
            return strings.isEmpty ? nil : strings
        }
        if let text = value as? String {
            let components = text
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return components.isEmpty ? nil : components
        }
        return nil
    }

    private func stringValue(from value: Any?) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private func intValue(from value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private func boolValue(from value: Any?) -> Bool? {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? NSNumber {
            return value.boolValue
        }
        if let value = value as? String {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "y", "on":
                return true
            case "false", "0", "no", "n", "off":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private func debugLog(_ message: String) {
        ArticleAIDebugLogger.log("[ArticleAIChat] \(message)")
    }

    private func debugLogError(_ prefix: String, error: Error) {
        let nsError = error as NSError
        ArticleAIDebugLogger.log("[ArticleAIChat] \(prefix): domain=\(nsError.domain), code=\(nsError.code), description=\(nsError.localizedDescription)")
    }

    private func debugDescription(_ value: Any, maxLength: Int) -> String {
        if JSONSerialization.isValidJSONObject(value),
            let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        {
            return truncate(text, maxLength: maxLength)
        }
        return truncate(String(describing: value), maxLength: maxLength)
    }

    private func toolFailureDetail(
        toolResult: String,
        toolName: String,
        toolCallID: String,
        arguments: [String: Any]
    ) -> ArticleAIToolFailureDetail? {
        let argumentPreview = debugDescription(arguments, maxLength: 800)
        let resultPreview = truncate(toolResult, maxLength: 1200)

        guard let data = toolResult.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data),
            let dict = json as? [String: Any]
        else {
            return ArticleAIToolFailureDetail(
                toolName: toolName,
                toolCallID: toolCallID,
                error: "Tool returned non-JSON result.",
                argumentsPreview: argumentPreview,
                resultPreview: resultPreview
            )
        }

        let ok = (dict["ok"] as? Bool) ?? false
        guard ok == false else {
            return nil
        }

        var detailParts: [String] = []
        if let exitCode = intValue(from: dict["exit_code"]) {
            detailParts.append("exit_code=\(exitCode)")
        }
        if let timedOut = dict["timed_out"] as? Bool {
            detailParts.append("timed_out=\(timedOut)")
        }
        if let stderr = stringValue(from: dict["stderr"]), !stderr.isEmpty {
            detailParts.append("stderr=\(truncate(stderr, maxLength: 260))")
        }
        if let stdout = stringValue(from: dict["stdout"]), !stdout.isEmpty {
            detailParts.append("stdout=\(truncate(stdout, maxLength: 220))")
        }

        let errorMessage = stringValue(from: dict["error"])
            ?? (detailParts.isEmpty ? "Tool returned `ok=false`." : detailParts.joined(separator: " | "))

        return ArticleAIToolFailureDetail(
            toolName: toolName,
            toolCallID: toolCallID,
            error: errorMessage,
            argumentsPreview: argumentPreview,
            resultPreview: resultPreview
        )
    }

    private func rejectedChangesToolResult(toolName: String, detail: String, example: String) -> String {
        let localMessage = "I rejected \(toolName) because `changes` must be a non-empty JSON object. This write was not applied to avoid unintended edits. Retry with explicit fields, for example \(example)."
        return toolResult([
            "ok": false,
            "rejected": true,
            "error": "Missing or invalid `changes` object.",
            "detail": detail,
            "local_assistant_message": localMessage,
        ])
    }

    private func mutationNoticeFromToolResult(toolName: String, toolResult: String) -> String? {
        guard toolName == "write_article" || toolName == "write_planet" else {
            return nil
        }
        guard
            let data = toolResult.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data),
            let payload = json as? [String: Any],
            (payload["ok"] as? Bool) == true
        else {
            return nil
        }

        let updatedFields = stringArrayValue(from: payload["updated_fields"]) ?? []
        let fieldSuffix: String = {
            guard !updatedFields.isEmpty else {
                return ""
            }
            return " Updated fields: \(updatedFields.joined(separator: ", "))."
        }()

        if toolName == "write_article" {
            return "I modified the article.\(fieldSuffix)"
        } else {
            return "I modified the planet.\(fieldSuffix)"
        }
    }

    private func assistantTextWithMutationNotices(baseText: String, mutationNotices: [String]) -> String {
        let trimmedBase = baseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mutationNotices.isEmpty else {
            return trimmedBase
        }

        let noticeBlock = mutationNotices.joined(separator: "\n")
        if trimmedBase.isEmpty {
            return noticeBlock
        }
        return "\(noticeBlock)\n\n\(trimmedBase)"
    }

    private func localAssistantMessageFromRejectedToolResult(_ toolResult: String) -> String? {
        guard
            let data = toolResult.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data),
            let payload = json as? [String: Any],
            (payload["rejected"] as? Bool) == true
        else {
            return nil
        }
        return stringValue(from: payload["local_assistant_message"])
    }

    private func toolResultSucceeded(_ toolResult: String) -> Bool? {
        guard
            let data = toolResult.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json["ok"] as? Bool
    }

    private func buildToolFailureAssistantMessage(
        model: String,
        reason: String,
        failures: [ArticleAIToolFailureDetail]
    ) -> String {
        var lines: [String] = [
            "I couldn't complete this request with tools.",
            "Reason: \(reason)",
            "Model: \(model)",
        ]

        let recentFailures = Array(failures.suffix(3))
        if !recentFailures.isEmpty {
            lines.append("Recent tool failures:")
            for (index, failure) in recentFailures.enumerated() {
                lines.append("\(index + 1). \(failure.toolName) (\(failure.toolCallID)): \(failure.error)")
                lines.append("   arguments: \(failure.argumentsPreview)")
                lines.append("   result: \(failure.resultPreview)")
            }
        } else {
            lines.append("No tool error payload was captured.")
        }

        lines.append("Try again with a smaller update (for example: \"use write_article with {\\\"changes\\\": {\\\"content\\\": \\\"...\\\"}}\"), or ask me to read first then write.")
        return lines.joined(separator: "\n")
    }

    private func toolResult(_ payload: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return #"{"ok":false,"error":"Failed to encode tool result."}"#
        }
        return text
    }

    private var systemPrompt: String {
        """
        You are a useful research assistant.
        Return only essential information.
        No small talk, no preambles like "here is", and do not ask follow-up questions at the end.
        If tools are available, use them when needed to read or update article/planet models or run shell commands.
        For article/planet edits, prefer read_article/write_article/read_planet/write_planet; only use shell if the user explicitly asks for shell.
        For write_article content generation, append to existing content by default; only replace full content when the user explicitly asks, by setting replace_content=true.
        If generated content starts with a Markdown H1 heading (# Title), put that heading text into changes.title and omit the H1 line from changes.content.
        """
    }

    private var articleContextPrefix: String {
        "You are helping with the following article."
    }

    private func articleContextMessage(title: String, content: String) -> String {
        """
        \(articleContextPrefix)

        Title: \(title)

        Content:
        \(content)
        """
    }

    private func currentArticleContextMessage() -> String {
        articleContextMessage(title: article.title, content: article.content)
    }

    private func refreshArticleContextAfterWriteIfNeeded(
        toolName: String,
        toolResult: String,
        workingMessages: inout [[String: Any]]
    ) {
        guard toolName == "write_article" else {
            return
        }
        guard let updatedContext = updatedArticleContextMessage(fromWriteArticleToolResult: toolResult) else {
            return
        }
        upsertArticleContextMessage(updatedContext, into: &workingMessages)
    }

    private func updatedArticleContextMessage(fromWriteArticleToolResult toolResult: String) -> String? {
        guard
            let data = toolResult.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data),
            let payload = json as? [String: Any],
            (payload["ok"] as? Bool) == true
        else {
            return nil
        }

        let updatedFields = Set(stringArrayValue(from: payload["updated_fields"]) ?? [])
        guard updatedFields.contains("title") || updatedFields.contains("content") else {
            return nil
        }

        guard let articlePayload = payload["article"] as? [String: Any] else {
            debugLog("write_article succeeded but article payload missing while refreshing chat context")
            return nil
        }

        let refreshedTitle = (articlePayload["title"] as? String) ?? ""
        let refreshedContent = (articlePayload["content"] as? String) ?? ""
        let refreshedContext = articleContextMessage(
            title: refreshedTitle,
            content: refreshedContent
        )
        debugLog("refreshing chat article context from write_article updatedFields=\(Array(updatedFields).sorted())")
        return refreshedContext
    }

    private func upsertArticleContextMessage(_ context: String, into messages: inout [[String: Any]]) {
        if let existingIndex = indexOfArticleContextMessage(in: messages) {
            var updated = messages[existingIndex]
            updated["content"] = context
            messages[existingIndex] = updated
            debugLog("updated existing article context message index=\(existingIndex)")
            return
        }

        let contextMessage: [String: Any] = [
            "role": "user",
            "content": context,
        ]
        if let systemIndex = messages.firstIndex(where: { ($0["role"] as? String) == "system" }) {
            let insertionIndex = min(systemIndex + 1, messages.count)
            messages.insert(contextMessage, at: insertionIndex)
            debugLog("inserted article context message index=\(insertionIndex)")
        } else {
            messages.insert(contextMessage, at: 0)
            debugLog("inserted article context message index=0 (no system message found)")
        }
    }

    private func indexOfArticleContextMessage(in messages: [[String: Any]]) -> Int? {
        messages.firstIndex(where: { message in
            guard (message["role"] as? String) == "user" else {
                return false
            }
            guard let content = message["content"] as? String else {
                return false
            }
            return content.hasPrefix(articleContextPrefix)
        })
    }

    private struct ShellCommandResult {
        let exitCode: Int
        let stdout: String
        let stderr: String
        let timedOut: Bool
    }

    private struct ShellWorkingDirectoryError: LocalizedError {
        let message: String
        var errorDescription: String? {
            message
        }
    }

    private func resolveShellWorkingDirectory(input: String?, repoRoot: URL) -> Result<URL, ShellWorkingDirectoryError> {
        guard let input = input else {
            return .success(repoRoot)
        }
        let candidate: URL = {
            if input.hasPrefix("/") {
                return URL(fileURLWithPath: input, isDirectory: true)
            }
            return repoRoot.appendingPathComponent(input, isDirectory: true)
        }()
        let resolved = candidate.standardizedFileURL
        let rootPath = repoRoot.standardizedFileURL.path
        let resolvedPath = resolved.path
        let insideRoot = resolvedPath == rootPath || resolvedPath.hasPrefix(rootPath + "/")
        guard insideRoot else {
            return .failure(ShellWorkingDirectoryError(message: "`working_directory` must stay under \(rootPath)"))
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDirectory)
        guard exists, isDirectory.boolValue else {
            return .failure(ShellWorkingDirectoryError(message: "Working directory does not exist: \(resolvedPath)"))
        }
        return .success(resolved)
    }

    private func runShellCommand(
        _ command: String,
        workingDirectory: URL,
        timeoutSeconds: Int
    ) throws -> ShellCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = workingDirectory

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdoutData = Data()
        var stderrData = Data()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stdoutData.append(data)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrData.append(data)
        }

        try process.run()

        var timedOut = false
        var forcedKill = false
        var forcedReturn = false

        let didFinishInTime = waitForProcessExit(process, timeout: TimeInterval(timeoutSeconds))
        if !didFinishInTime {
            timedOut = true
            if process.isRunning {
                process.terminate()
                let exitedAfterTerminate = waitForProcessExit(process, timeout: 1.0)
                if !exitedAfterTerminate && process.isRunning {
                    forcedKill = true
                    _ = Darwin.kill(process.processIdentifier, SIGKILL)
                    let exitedAfterKill = waitForProcessExit(process, timeout: 1.0)
                    if !exitedAfterKill && process.isRunning {
                        forcedReturn = true
                    }
                }
            }
        }

        if !process.isRunning {
            process.waitUntilExit()
        }
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        if !forcedReturn {
            let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            if !remainingStdout.isEmpty {
                stdoutData.append(remainingStdout)
            }
            let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            if !remainingStderr.isEmpty {
                stderrData.append(remainingStderr)
            }
        } else {
            let forceTimeoutMessage = "\n[timeout] process did not exit after SIGKILL grace period"
            if let forceTimeoutData = forceTimeoutMessage.data(using: .utf8) {
                stderrData.append(forceTimeoutData)
            }
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
        }

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let exitCode: Int = {
            if forcedReturn {
                return forcedKill ? Int(SIGKILL) : -1
            }
            return Int(process.terminationStatus)
        }()

        return ShellCommandResult(
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            timedOut: timedOut
        )
    }

    private func waitForProcessExit(_ process: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        return !process.isRunning
    }

    private func truncate(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else {
            return text
        }
        let index = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<index]) + "\n...[truncated]"
    }
}
