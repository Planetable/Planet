//
//  PlanetSettingsAIView.swift
//  Planet
//
//  Created by Xin Liu on 2/21/26.
//

import SwiftUI

struct PlanetSettingsAIView: View {
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
                TextField("API Base URL", text: $aiAPIBase)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: aiAPIBase) { newValue in
                        UserDefaults.standard.set(newValue, forKey: .settingsAIAPIBase)
                        scheduleCheck()
                    }
            }
            .padding(.top, 6)

            Section {
                ZStack {
                    TextField("API Token", text: $aiAPIToken)
                        .opacity(isShowingToken ? 1.0 : 0.0)
                    SecureField("API Token", text: $aiAPIToken)
                        .opacity(!isShowingToken ? 1.0 : 0.0)
                    HStack {
                        Spacer()
                        Button {
                            isShowingToken.toggle()
                        } label: {
                            Image(systemName: !isShowingToken ? "eye.slash" : "eye")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14, alignment: .center)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                }
                .textFieldStyle(.roundedBorder)
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

            Section {
                TextField("Preferred Model", text: $aiPreferredModel)
                    .textFieldStyle(.roundedBorder)
                    .focused($isModelFieldFocused)
                    .onChange(of: aiPreferredModel) { newValue in
                        UserDefaults.standard.set(newValue, forKey: .settingsAIPreferredModel)
                        schedulePreferredModelCheck()
                    }

                if showSuggestions {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredModelIDs, id: \.self) { modelID in
                                Text(modelID)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        aiPreferredModel = modelID
                                        isModelFieldFocused = false
                                    }
                                if modelID != filteredModelIDs.last {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }
            }

            Section {
                HStack(spacing: 8) {
                    statusCircle
                    statusLabel
                }
                .padding(.top, 4)
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
        }
    }

    @ViewBuilder
    private var statusCircle: some View {
        switch modelStatus {
        case .idle:
            Circle()
                .frame(width: 10, height: 10)
                .foregroundStyle(Color.gray)
        case .checking:
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.mini)
                .frame(width: 10, height: 10)
        case .ok(_, let modelFound):
            Circle()
                .frame(width: 10, height: 10)
                .foregroundStyle(modelFound ? Color.green : Color.orange)
        case .error:
            Circle()
                .frame(width: 10, height: 10)
                .foregroundStyle(Color.red)
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
        let urlString = base.hasSuffix("/") ? "\(base)models" : "\(base)/models"
        guard let url = URL(string: urlString) else {
            await MainActor.run { setModelStatus(.error("Invalid URL")) }
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
}

struct PlanetSettingsAIView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetSettingsAIView()
    }
}
