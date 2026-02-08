import AVFoundation
import AudioToolbox
import UIKit
import UserNotifications

@Observable
final class AlarmService {
    var isActive = false
    var message: String?

    private var audioPlayer: AVAudioPlayer?
    private var vibrationTimer: Timer?
    private var previousVolume: Float?

    func start(sound: String, message: String?) {
        self.message = message
        isActive = true

        configureAudioSession()
        let volume = volumeLevel(for: sound)
        setSystemVolume(volume)
        playAlarmTone()

        if sound == "hell" {
            startVibrationLoop()
        }

        postAlarmNotification(message: message)
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        vibrationTimer?.invalidate()
        vibrationTimer = nil
        isActive = false
        message = nil
        restoreVolume()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["active_alarm"])
    }

    // MARK: - Private

    private func postAlarmNotification(message: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = message ?? "Alarm is ringing"
        content.interruptionLevel = .critical
        content.categoryIdentifier = "alarm"

        let request = UNNotificationRequest(
            identifier: "active_alarm",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    private func volumeLevel(for sound: String) -> Float {
        switch sound {
        case "loud", "hell": return 1.0
        default: return 0.7
        }
    }

    private func setSystemVolume(_ level: Float) {
        // AVAudioPlayer volume (per-player, not system volume)
        // System volume requires MPVolumeView which is deprecated for programmatic use.
        // We set player volume to max and rely on audio session category.
        previousVolume = level
    }

    private func restoreVolume() {
        previousVolume = nil
    }

    private func playAlarmTone() {
        guard let data = generateAlarmWAV() else { return }
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.numberOfLoops = -1 // loop forever
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
        } catch {
            // Fallback: system alert sound
            AudioServicesPlayAlertSound(SystemSoundID(1005))
        }
    }

    private func startVibrationLoop() {
        vibrationTimer?.invalidate()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    /// Generate a simple alarm WAV (880Hz sine wave, 2 seconds, 16-bit PCM)
    private func generateAlarmWAV() -> Data? {
        let sampleRate: Double = 44100
        let duration: Double = 2.0
        let frequency: Double = 880.0
        let sampleCount = Int(sampleRate * duration)
        let amplitude: Double = 32000

        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            // Alternating tone for urgency: 880Hz for 0.25s, 660Hz for 0.25s
            let freq = Int(t * 4) % 2 == 0 ? frequency : 660.0
            let value = sin(2.0 * .pi * freq * t) * amplitude
            samples.append(Int16(clamping: Int(value)))
        }

        var data = Data()
        // WAV header
        let dataSize = UInt32(sampleCount * 2)
        let fileSize = dataSize + 36
        data.append(contentsOf: "RIFF".utf8)
        data.append(littleEndian: fileSize)
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(littleEndian: UInt32(16)) // chunk size
        data.append(littleEndian: UInt16(1))  // PCM format
        data.append(littleEndian: UInt16(1))  // mono
        data.append(littleEndian: UInt32(44100)) // sample rate
        data.append(littleEndian: UInt32(88200)) // byte rate
        data.append(littleEndian: UInt16(2))  // block align
        data.append(littleEndian: UInt16(16)) // bits per sample
        data.append(contentsOf: "data".utf8)
        data.append(littleEndian: dataSize)

        for sample in samples {
            data.append(littleEndian: sample)
        }

        return data
    }
}

// MARK: - Data helper for little-endian append

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var le = value.littleEndian
        append(UnsafeBufferPointer(start: &le, count: 1))
    }
}
