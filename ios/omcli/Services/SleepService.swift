import UIKit

@Observable
final class SleepService {
    var isActive = false

    func start() {
        isActive = true
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func stop() {
        isActive = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
