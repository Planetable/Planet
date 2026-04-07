import AVFoundation
import NaturalLanguage
import SwiftUI
import SwiftSoup

@MainActor class ArticleSpeechPlayerViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = ArticleSpeechPlayerViewModel()

    @Published var isSpeaking: Bool = false
    @Published var isPaused: Bool = false
    @Published var title: String = ""
    @Published var currentLanguage: String = ""
    @Published var voiceIdentifier: String = "" {
        didSet {
            guard !currentLanguage.isEmpty else { return }
            var prefs = voicePrefsPerLanguage
            if voiceIdentifier.isEmpty {
                prefs.removeValue(forKey: currentLanguage)
            } else {
                prefs[currentLanguage] = voiceIdentifier
            }
            UserDefaults.standard.set(prefs, forKey: .settingsSpeechVoicePerLanguage)
            restartWithNewVoice()
        }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var fullText: String = ""
    private var lastSpokenLocation: Int = 0
    private var currentUtterance: AVSpeechUtterance?
    private var isRestartingWithNewVoice: Bool = false

    private var voicePrefsPerLanguage: [String: String] {
        UserDefaults.standard.dictionary(forKey: .settingsSpeechVoicePerLanguage) as? [String: String] ?? [:]
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Language detection

    /// Returns the base language code (e.g. "en", "zh", "ja", "ko") for the given text.
    nonisolated static func detectLanguage(of text: String) -> String? {
        // Strip HTML tags
        let plainText = text.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )

        // Fast path: count CJK characters to detect Chinese/Japanese/Korean
        var cjkCount = 0
        var totalCount = 0
        for scalar in plainText.unicodeScalars {
            if scalar.properties.isWhitespace { continue }
            totalCount += 1
            // CJK Unified Ideographs + Extensions + CJK Compatibility
            if (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
                || (0x20000...0x2A6DF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
            {
                cjkCount += 1
            }
        }
        let latinCount = plainText.unicodeScalars.filter {
            (0x41...0x5A).contains($0.value) || (0x61...0x7A).contains($0.value)
        }.count
        if cjkCount > latinCount {
            // Distinguish Japanese (has hiragana/katakana) from Chinese
            let hasKana = plainText.unicodeScalars.contains {
                (0x3040...0x309F).contains($0.value) || (0x30A0...0x30FF).contains($0.value)
            }
            if hasKana { return "ja" }

            let hasHangul = plainText.unicodeScalars.contains {
                (0xAC00...0xD7AF).contains($0.value) || (0x1100...0x11FF).contains($0.value)
            }
            if hasHangul { return "ko" }

            return "zh"
        }

        // Fall back to NLLanguageRecognizer for non-CJK text
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(plainText)
        guard let lang = recognizer.dominantLanguage else { return nil }
        return String(lang.rawValue.prefix(2))
    }

    nonisolated private static func voiceMatchesLanguage(_ voice: AVSpeechSynthesisVoice, _ language: String) -> Bool {
        voice.language.hasPrefix(language + "-") || voice.language == language
    }

    nonisolated static func hasVoices(forLanguage language: String) -> Bool {
        AVSpeechSynthesisVoice.speechVoices().contains { voiceMatchesLanguage($0, language) }
    }

    func voicesForCurrentLanguage() -> [AVSpeechSynthesisVoice] {
        guard !currentLanguage.isEmpty else { return [] }
        let matched = AVSpeechSynthesisVoice.speechVoices()
            .filter { Self.voiceMatchesLanguage($0, currentLanguage) }
        let hasMultipleRegions = Set(matched.map(\.language)).count > 1
        return matched.sorted { a, b in
            if a.quality.rawValue != b.quality.rawValue { return a.quality.rawValue > b.quality.rawValue }
            if hasMultipleRegions, a.language != b.language { return a.language < b.language }
            return a.name < b.name
        }
    }

    static func voiceDisplayName(_ voice: AVSpeechSynthesisVoice, showRegion: Bool) -> String {
        if showRegion {
            return "\(voice.name) (\(voice.language))"
        }
        return voice.name
    }

    nonisolated private static func preferredDefaultVoiceIdentifier(for language: String) -> String? {
        let preferences: [(language: String?, name: String)] = switch language {
        case "en":
            [(nil, "Alex"), (nil, "Reed")]
        case "zh":
            [("zh-CN", "Tingting")]
        default:
            []
        }

        guard !preferences.isEmpty else { return nil }

        let voices = AVSpeechSynthesisVoice.speechVoices()
        for preference in preferences {
            if let voice = voices.first(where: { voice in
                voiceMatchesLanguage(voice, language)
                    && voice.name == preference.name
                    && (preference.language == nil || voice.language == preference.language)
            }) {
                return voice.identifier
            }
        }

        return nil
    }

    // MARK: - Playback

    func speak(text: String, title: String, language: String) {
        stop()
        self.title = title
        self.currentLanguage = language
        self.fullText = text
        self.lastSpokenLocation = 0

        // Restore saved voice for this language, discard if it doesn't match
        var savedIdentifier = voicePrefsPerLanguage[language] ?? ""
        if !savedIdentifier.isEmpty {
            if let voice = AVSpeechSynthesisVoice(identifier: savedIdentifier),
                Self.voiceMatchesLanguage(voice, language)
            {
                // valid
            } else {
                savedIdentifier = ""
                var prefs = voicePrefsPerLanguage
                prefs.removeValue(forKey: language)
                UserDefaults.standard.set(prefs, forKey: .settingsSpeechVoicePerLanguage)
            }
        }
        if savedIdentifier.isEmpty {
            savedIdentifier = Self.preferredDefaultVoiceIdentifier(for: language) ?? ""
        }
        voiceIdentifier = savedIdentifier

        speakFromCurrentPosition()
    }

    private func speakFromCurrentPosition() {
        let remainingText: String
        if lastSpokenLocation > 0, lastSpokenLocation < fullText.count {
            let idx = fullText.index(fullText.startIndex, offsetBy: lastSpokenLocation)
            remainingText = String(fullText[idx...])
        } else {
            remainingText = fullText
        }

        let utterance = AVSpeechUtterance(string: remainingText)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        if !voiceIdentifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else if !currentLanguage.isEmpty {
            // Use the best available voice for the detected language
            utterance.voice = AVSpeechSynthesisVoice(language: currentLanguage)
        }

        currentUtterance = utterance
        synthesizer.speak(utterance)
        isSpeaking = true
        isPaused = false
    }

    private func restartWithNewVoice() {
        guard isSpeaking else { return }
        isRestartingWithNewVoice = true
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func clearPlaybackState() {
        isSpeaking = false
        isPaused = false
        title = ""
        currentLanguage = ""
        fullText = ""
        lastSpokenLocation = 0
        currentUtterance = nil
        isRestartingWithNewVoice = false
    }

    private func finishUtterance(_ utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        currentUtterance = nil

        if isRestartingWithNewVoice {
            isRestartingWithNewVoice = false
            speakFromCurrentPosition()
            return
        }

        clearPlaybackState()
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
    }

    func resume() {
        synthesizer.continueSpeaking()
        isPaused = false
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        clearPlaybackState()
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            guard utterance === self.currentUtterance else { return }
            // characterRange is relative to the current utterance text, which may be
            // a substring if we resumed from a position. Translate back to fullText offset.
            let utteranceOffset = self.fullText.count - utterance.speechString.count
            self.lastSpokenLocation = utteranceOffset + characterRange.location
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.finishUtterance(utterance)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.finishUtterance(utterance)
        }
    }

    // MARK: - Text extraction

    static func extractPlainText(from article: FollowingArticleModel) -> String {
        var text = article.title + "\n\n"
        let content = article.content
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let doc = try? SwiftSoup.parseBodyFragment(content),
                let bodyText = try? doc.text()
            {
                text += bodyText
            } else {
                text += content
            }
        }
        return text
    }
}

struct ArticleSpeechPlayer: View {
    @ObservedObject var viewModel = ArticleSpeechPlayerViewModel.shared

    var body: some View {
        if viewModel.isSpeaking {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                HStack {
                    if viewModel.isPaused {
                        Button {
                            viewModel.resume()
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .frame(width: 24, height: 24)
                        .buttonStyle(.borderless)
                    } else {
                        Button {
                            viewModel.pause()
                        } label: {
                            Image(systemName: "pause.fill")
                        }
                        .frame(width: 24, height: 24)
                        .buttonStyle(.borderless)
                    }

                    Image(systemName: "waveform")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Text(viewModel.title)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    let voices = viewModel.voicesForCurrentLanguage()
                    let showRegion = Set(voices.map(\.language)).count > 1
                    Picker("", selection: $viewModel.voiceIdentifier) {
                        Text("Default").tag("")
                        ForEach(voices, id: \.identifier) { voice in
                            Text(ArticleSpeechPlayerViewModel.voiceDisplayName(voice, showRegion: showRegion))
                                .tag(voice.identifier)
                        }
                    }
                    .labelsHidden()
                    .frame(width: showRegion ? 200 : 150)

                    Button {
                        viewModel.stop()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 24, height: 24)
                }
                .padding(.top, 6)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
    }
}
