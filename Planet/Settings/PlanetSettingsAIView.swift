//
//  PlanetSettingsAIView.swift
//  Planet
//
//  Created by Xin Liu on 2/21/26.
//

import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

struct PlanetSettingsAIView: View {
    private enum Layout {
        static let secondaryRowLeadingInset: CGFloat = 8
    }

    @State private var aiAPIBase: String = UserDefaults.standard.string(forKey: .settingsAIAPIBase) ?? ""
    @State private var aiAPIToken: String = ""
    @State private var isShowingToken: Bool = false
    @State private var aiPreferredModel: String = UserDefaults.standard.string(forKey: .settingsAIPreferredModel) ?? "claude-sonnet-4-6"
    @State private var availableModelIDs: [String] = []
    @FocusState private var isModelFieldFocused: Bool

    enum ModelStatus {
        case idle
        case checking
        case ok(count: Int, modelFound: Bool)
        case error(String)
    }
    @State private var modelStatus: ModelStatus = .idle
    @State private var checkTask: Task<Void, Never>? = nil
    @State private var preferredModelCheckTask: Task<Void, Never>? = nil
    @State private var onDeviceAIState: StatusIndicatorState = .idle
    @State private var onDeviceAILabel: String = "Checking…"
    @State private var ollamaDetected: Bool = false
    @State private var lmStudioDetected: Bool = false

    private var hasInsecureHTTPError: Bool {
        let base = aiAPIBase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty,
              let url = URL(string: base),
              url.scheme?.lowercased() == "http"
        else { return false }
        do {
            _ = try AIEndpointSecurityPolicy.modelsURL(base: base)
            return false
        } catch {
            return error.localizedDescription == AIEndpointSecurityPolicy.insecureHTTPErrorDescription
        }
    }

    private var isUsingOllama: Bool {
        let base = aiAPIBase.lowercased()
        return base.contains(":11434") && (
            base.hasPrefix("http://localhost:") ||
            base.hasPrefix("http://127.") ||
            base.hasPrefix("http://0.0.0.0:") ||
            base.hasPrefix("http://10.") ||
            base.hasPrefix("http://100.") ||
            base.hasPrefix("http://192.168.")
        )
    }

    private var isUsingLMStudio: Bool {
        let base = aiAPIBase.lowercased()
        return base.contains(":1234") && (
            base.hasPrefix("http://localhost:") ||
            base.hasPrefix("http://127.") ||
            base.hasPrefix("http://0.0.0.0:") ||
            base.hasPrefix("http://10.") ||
            base.hasPrefix("http://100.") ||
            base.hasPrefix("http://192.168.")
        )
    }

    private var filteredModelIDs: [String] {
        let query = aiPreferredModel.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return availableModelIDs }
        return availableModelIDs.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private var showSuggestions: Bool {
        isModelFieldFocused && !availableModelIDs.isEmpty && !filteredModelIDs.isEmpty
    }

    var body: some View {
        Form {
            Section {
                PlanetSettingsContainer {
                    VStack(alignment: .leading, spacing: PlanetSettingsSharedLayout.descriptionSpacing) {
                        PlanetSettingsRow("API Base URL") {
                            TextField("", text: $aiAPIBase)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("API Base URL")
                                .onChange(of: aiAPIBase) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: .settingsAIAPIBase)
                                    scheduleCheck()
                                }
                        }

                        if hasInsecureHTTPError {
                            PlanetSettingsControlRow(alignment: .top) {
                                Text(AIEndpointSecurityPolicy.insecureHTTPErrorDescription)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if ollamaDetected {
                            PlanetSettingsControlRow {
                                HStack(spacing: 8) {
                                    StatusIndicatorView(state: .success)
                                    if isUsingOllama {
                                        Text("Using Ollama")
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Text("Ollama detected on localhost")
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                        Button("Use Ollama") {
                                            aiAPIBase = "http://localhost:11434/v1"
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, Layout.secondaryRowLeadingInset)
                            }
                        }

                        if lmStudioDetected {
                            PlanetSettingsControlRow {
                                HStack(spacing: 8) {
                                    StatusIndicatorView(state: .success)
                                    if isUsingLMStudio {
                                        Text("Using LM Studio")
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Text("LM Studio detected on localhost")
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                        Button("Use LM Studio") {
                                            aiAPIBase = "http://localhost:1234/v1"
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, Layout.secondaryRowLeadingInset)
                            }
                        }
                    }

                    PlanetSettingsRow("API Token") {
                        ZStack {
                            TextField("", text: $aiAPIToken)
                                .opacity(isShowingToken ? 1.0 : 0.0)
                                .accessibilityHidden(!isShowingToken)
                            SecureField("", text: $aiAPIToken)
                                .opacity(!isShowingToken ? 1.0 : 0.0)
                                .accessibilityHidden(isShowingToken)
                            HStack {
                                Spacer()
                                Button {
                                    isShowingToken.toggle()
                                } label: {
                                    Label(
                                        isShowingToken ? "Hide API Token" : "Show API Token",
                                        systemImage: !isShowingToken ? "eye.slash" : "eye"
                                    )
                                    .labelStyle(.iconOnly)
                                    .font(.system(size: 14))
                                    .frame(width: 14, height: 14, alignment: .center)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                        }
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("API Token")
                        .onChange(of: aiAPIToken) { newValue in
                            Task { @MainActor in
                                do {
                                    if newValue.isEmpty {
                                        try KeychainHelper.shared.delete(forKey: .settingsAIAPIToken)
                                    } else {
                                        try KeychainHelper.shared.saveValue(newValue, forKey: .settingsAIAPIToken)
                                    }
                                } catch {
                                    debugPrint("failed to save AI API token: \(error)")
                                }
                            }
                            scheduleCheck()
                        }
                    }

                    VStack(alignment: .leading, spacing: PlanetSettingsSharedLayout.descriptionSpacing) {
                        PlanetSettingsRow("Preferred Model") {
                            TextField("", text: $aiPreferredModel)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Preferred Model")
                                .focused($isModelFieldFocused)
                                .onChange(of: aiPreferredModel) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: .settingsAIPreferredModel)
                                    schedulePreferredModelCheck()
                                }
                        }

                        if showSuggestions {
                            PlanetSettingsControlRow(alignment: .top) {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(filteredModelIDs, id: \.self) { modelID in
                                            Button {
                                                aiPreferredModel = modelID
                                                isModelFieldFocused = false
                                            } label: {
                                                Text(modelID)
                                                    .font(.system(.body, design: .monospaced))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 5)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            if modelID != filteredModelIDs.last {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 160)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.leading, Layout.secondaryRowLeadingInset)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: PlanetSettingsSharedLayout.descriptionSpacing) {
                        PlanetSettingsControlRow(alignment: .top) {
                            HStack(spacing: 8) {
                                StatusIndicatorView(state: statusIndicatorState)
                                statusLabel
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, Layout.secondaryRowLeadingInset)
                        }

                        PlanetSettingsControlRow(alignment: .top) {
                            HStack(alignment: .top, spacing: 8) {
                                StatusIndicatorView(state: onDeviceAIState)
                                onDeviceAIStatusLabel
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, Layout.secondaryRowLeadingInset)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()
        }
        .padding()
        .task {
            do {
                let token = try KeychainHelper.shared.loadValue(forKey: .settingsAIAPIToken)
                if !token.isEmpty {
                    aiAPIToken = token
                }
            } catch {
                aiAPIToken = ""
            }
            scheduleCheck()
            checkOnDeviceAI()
            checkOllama()
            checkLMStudio()
        }
    }

    private var statusIndicatorState: StatusIndicatorState {
        switch modelStatus {
        case .idle:
            .idle
        case .checking:
            .checking
        case .ok(_, let modelFound):
            modelFound ? .success : .warning
        case .error:
            .error
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch modelStatus {
        case .idle:
            Text("Not configured")
                .foregroundStyle(.secondary)
        case .checking:
            Text("Checking…")
                .foregroundStyle(.secondary)
        case .ok(let count, let modelFound):
            if modelFound {
                Text("\(count) models available, preferred model supported")
            } else {
                Text("\(count) models available, preferred model not found")
                    .foregroundStyle(.orange)
            }
        case .error(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var onDeviceAIStatusLabel: some View {
        switch onDeviceAIState {
        case .success:
            Text(onDeviceAILabel)
        case .warning:
            Text(onDeviceAILabel)
                .foregroundStyle(.orange)
        case .error:
            Text(onDeviceAILabel)
                .foregroundStyle(.red)
        default:
            Text(onDeviceAILabel)
                .foregroundStyle(.secondary)
        }
    }

    private func setModelStatus(_ status: ModelStatus) {
        modelStatus = status
        if case .ok(_, let modelFound) = status {
            UserDefaults.standard.set(modelFound, forKey: .settingsAIIsReady)
        } else {
            UserDefaults.standard.set(false, forKey: .settingsAIIsReady)
        }
    }

    private func schedulePreferredModelCheck() {
        preferredModelCheckTask?.cancel()
        let preferredModel = aiPreferredModel
        preferredModelCheckTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard case .ok(let count, _) = modelStatus else { return }
                setModelStatus(.ok(count: count, modelFound: availableModelIDs.contains(preferredModel)))
            }
        }
    }

    private func scheduleCheck() {
        checkTask?.cancel()
        let base = aiAPIBase
        let token = aiAPIToken
        let preferredModel = aiPreferredModel
        guard !base.isEmpty else {
            setModelStatus(.idle)
            return
        }
        setModelStatus(.checking)
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await fetchModels(base: base, token: token, preferredModel: preferredModel)
        }
    }

    private func fetchModels(base: String, token: String, preferredModel: String) async {
        let url: URL
        do {
            url = try AIEndpointSecurityPolicy.modelsURL(base: base)
        } catch {
            await MainActor.run { setModelStatus(.error(error.localizedDescription)) }
            return
        }
        var request = URLRequest(url: url)
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                await MainActor.run { setModelStatus(.error("Invalid response")) }
                return
            }
            guard http.statusCode == 200 else {
                await MainActor.run { setModelStatus(.error("HTTP \(http.statusCode)")) }
                return
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = json?["data"] as? [[String: Any]] ?? []
            let modelIDs = models.compactMap { $0["id"] as? String }.sorted()
            let modelFound = modelIDs.contains(preferredModel)
            await MainActor.run {
                availableModelIDs = modelIDs
                setModelStatus(.ok(count: models.count, modelFound: modelFound))
            }
        } catch {
            await MainActor.run { setModelStatus(.error(error.localizedDescription)) }
        }
    }

    private func checkOllama() {
        Task {
            let url = URL(string: "http://localhost:11434/api/tags")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 2
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    await MainActor.run { ollamaDetected = true }
                }
            } catch {
                await MainActor.run { ollamaDetected = false }
            }
        }
    }

    private func checkLMStudio() {
        Task {
            let url = URL(string: "http://localhost:1234/v1/models")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 2
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    await MainActor.run { lmStudioDetected = true }
                }
            } catch {
                await MainActor.run { lmStudioDetected = false }
            }
        }
    }

    private func checkOnDeviceAI() {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                onDeviceAIState = .success
                onDeviceAILabel = "Apple Intelligence model available"
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    onDeviceAIState = .error
                    onDeviceAILabel = "On-device AI is not available because this device is not eligible"
                case .modelNotReady:
                    onDeviceAIState = .warning
                    onDeviceAILabel = "On-device AI is not available because the model is not ready"
                case .appleIntelligenceNotEnabled:
                    onDeviceAIState = .warning
                    onDeviceAILabel = "On-device AI is not available because Apple Intelligence is not enabled"
                @unknown default:
                    onDeviceAIState = .warning
                    onDeviceAILabel = "On-device AI is not available"
                }
            @unknown default:
                onDeviceAIState = .warning
                onDeviceAILabel = "On-device AI availability is unknown"
            }
        } else {
            onDeviceAIState = .idle
            onDeviceAILabel = "On-device AI is not available because this Mac is not running macOS 26 or later"
        }
        #else
        onDeviceAIState = .idle
        onDeviceAILabel = "On-device AI is not available because this build lacks the macOS 26 SDK"
        #endif
    }
}

struct PlanetSettingsAIView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsAIView()
    }
}
