import SwiftUI

struct PlanetAIChatSession: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date

    init(id: UUID = UUID(), title: String = "New Session", createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
    }
}

@MainActor
class PlanetAIChatSessionStore: ObservableObject {
    static let shared = PlanetAIChatSessionStore()

    @Published var sessions: [PlanetAIChatSession] = []
    @Published var selectedSessionID: UUID? {
        didSet {
            saveSelectedSessionID()
        }
    }

    private var indexURL: URL {
        URLUtils.repoPath().appendingPathComponent("planet-ai-sessions-index.json")
    }

    private var sessionsDirectory: URL {
        URLUtils.repoPath().appendingPathComponent("planet-ai-sessions", isDirectory: true)
    }

    init() {
        load()
        if sessions.isEmpty {
            migrateOrCreateFirst()
        }
        restoreSelectedSessionID()
    }

    func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([PlanetAIChatSession].self, from: data)
        else { return }
        sessions = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    func createSession() -> PlanetAIChatSession {
        let session = PlanetAIChatSession()
        sessions.append(session)
        selectedSessionID = session.id
        save()
        return session
    }

    func deleteSession(_ session: PlanetAIChatSession) {
        sessions.removeAll { $0.id == session.id }
        let chatFile = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        try? FileManager.default.removeItem(at: chatFile)
        if selectedSessionID == session.id {
            selectedSessionID = sessions.last?.id
        }
        if sessions.isEmpty {
            _ = createSession()
        }
        save()
    }

    func updateSessionTitle(_ sessionID: UUID, firstMessage: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }),
              sessions[index].title == "New Session"
        else { return }
        let trimmed = firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.count > 40 ? String(trimmed.prefix(40)) + "\u{2026}" : trimmed
        if !title.isEmpty {
            sessions[index].title = title
            save()
        }
    }

    private func restoreSelectedSessionID() {
        if let storedID = UserDefaults.standard.string(forKey: .settingsAILastChatSessionID),
           let sessionID = UUID(uuidString: storedID),
           sessions.contains(where: { $0.id == sessionID }) {
            selectedSessionID = sessionID
            return
        }

        selectedSessionID = sessions.first?.id
        saveSelectedSessionID()
    }

    private func saveSelectedSessionID() {
        guard let selectedSessionID else {
            UserDefaults.standard.removeObject(forKey: .settingsAILastChatSessionID)
            return
        }
        UserDefaults.standard.set(selectedSessionID.uuidString, forKey: .settingsAILastChatSessionID)
    }

    private func migrateOrCreateFirst() {
        let legacyFile = URLUtils.repoPath().appendingPathComponent("planet-ai-chat.json")
        if FileManager.default.fileExists(atPath: legacyFile.path) {
            let session = PlanetAIChatSession(title: "Session 1")
            sessions.append(session)
            try? FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
            let dest = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
            try? FileManager.default.moveItem(at: legacyFile, to: dest)
        } else {
            sessions.append(PlanetAIChatSession())
        }
        save()
    }
}

// MARK: - Split view

struct PlanetAIChatSessionsSplitView: View {
    var body: some View {
        NavigationView {
            PlanetAIChatSessionSidebar()

            PlanetAIChatSessionContentView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlanetAIChatSessionSidebar: View {
    @EnvironmentObject var store: PlanetAIChatSessionStore
    @State private var sessionToDelete: PlanetAIChatSession? = nil

    var body: some View {
        List(selection: $store.selectedSessionID) {
            ForEach(store.sessions) { session in
                PlanetAIChatSessionSidebarRow(session: session, sessionToDelete: $sessionToDelete)
                    .tag(session.id)
                    .contextMenu {
                        Button("New Session") {
                            _ = store.createSession()
                        }

                        Button("Delete Session", role: .destructive) {
                            sessionToDelete = session
                        }
                        .disabled(store.sessions.count <= 1)
                    }
            }
        }
        .listStyle(.sidebar)
        .frame(
            minWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN,
            idealWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MIN,
            maxWidth: PlanetUI.WINDOW_SIDEBAR_WIDTH_MAX,
            minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN,
            idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN,
            maxHeight: .infinity
        )
        .alert("Delete Session", isPresented: Binding<Bool>(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    store.deleteSession(session)
                    sessionToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: {
            Text("This will remove all messages for this session. This action cannot be undone.")
        }
    }
}

private struct PlanetAIChatSessionSidebarRow: View {
    @EnvironmentObject var store: PlanetAIChatSessionStore
    let session: PlanetAIChatSession
    @Binding var sessionToDelete: PlanetAIChatSession?

    var body: some View {
        HStack(spacing: 8) {
            Text(session.title)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(role: .destructive) {
                sessionToDelete = session
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(store.sessions.count <= 1)
            .help("Delete Session")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Content area

struct PlanetAIChatSessionContentView: View {
    @EnvironmentObject var store: PlanetAIChatSessionStore

    var body: some View {
        if let selectedID = store.selectedSessionID {
            ArticleAIChatView(planetWide: true, sessionID: selectedID)
                .id(selectedID)
                .environment(\.planetAIChatSessionStore, store)
                .frame(
                    minWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN,
                    idealWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN,
                    maxWidth: .infinity,
                    minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN,
                    idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN,
                    maxHeight: .infinity
                )
        } else {
            VStack(spacing: 8) {
                Text("No Session Selected")
                    .font(.headline)
                Text("Choose a session from the sidebar or create a new one.")
                    .foregroundColor(.secondary)
            }
            .frame(
                minWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN,
                idealWidth: PlanetUI.WINDOW_CONTENT_WIDTH_MIN,
                maxWidth: .infinity,
                minHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN,
                idealHeight: PlanetUI.WINDOW_CONTENT_HEIGHT_MIN,
                maxHeight: .infinity
            )
        }
    }
}

// MARK: - Environment key

private struct PlanetAIChatSessionStoreKey: EnvironmentKey {
    static let defaultValue: PlanetAIChatSessionStore? = nil
}

extension EnvironmentValues {
    var planetAIChatSessionStore: PlanetAIChatSessionStore? {
        get { self[PlanetAIChatSessionStoreKey.self] }
        set { self[PlanetAIChatSessionStoreKey.self] = newValue }
    }
}
