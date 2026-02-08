import UIKit

@Observable
final class SleepService {
    var isActive: Bool {
        didSet { UserDefaults.standard.set(isActive, forKey: "sleep_mode") }
    }

    init() {
        isActive = UserDefaults.standard.bool(forKey: "sleep_mode")
        if isActive {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }

    func start() {
        isActive = true
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func stop() {
        isActive = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
