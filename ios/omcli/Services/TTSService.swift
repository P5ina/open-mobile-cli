import AVFoundation

final class TTSService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, voice: String?) async {
        let utterance = AVSpeechUtterance(string: text)
        if let voice, let avVoice = AVSpeechSynthesisVoice(identifier: voice)
            ?? AVSpeechSynthesisVoice(language: voice) {
            utterance.voice = avVoice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            continuation?.resume()
            continuation = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        MainActor.assumeIsolated {
            continuation?.resume()
            continuation = nil
        }
    }
}
