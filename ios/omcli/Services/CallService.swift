import CallKit
import PushKit

@Observable
final class CallService: NSObject, CXProviderDelegate, PKPushRegistryDelegate {
    @ObservationIgnored private var provider: CXProvider?
    @ObservationIgnored private var voipRegistry: PKPushRegistry?
    @ObservationIgnored private var activeCallUUID: UUID?

    @ObservationIgnored var onAlarmAnswer: ((String?, String?) -> Void)?
    @ObservationIgnored var onAlarmDecline: (() -> Void)?
    @ObservationIgnored var sendVoipToken: ((String) -> Void)?

    @ObservationIgnored private var pendingAlarmSound: String?
    @ObservationIgnored private var pendingAlarmMessage: String?

    /// Must be called from didFinishLaunchingWithOptions — before PushKit can deliver any push.
    func setup() {
        let config = CXProviderConfiguration()
        config.supportsVideo = false
        config.maximumCallsPerCallGroup = 1

        provider = CXProvider(configuration: config)
        provider?.setDelegate(self, queue: .main)

        voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
    }

    func endActiveCall() {
        guard let uuid = activeCallUUID else { return }
        let controller = CXCallController()
        let action = CXEndCallAction(call: uuid)
        controller.request(CXTransaction(action: action)) { error in
            if let error {
                print("CallService: failed to end call: \(error)")
            }
        }
    }

    // MARK: - PKPushRegistryDelegate

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("CallService: VoIP token: \(token)")
        sendVoipToken?(token)
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType
    ) {
        guard type == .voIP else { return }

        print("CallService: received VoIP push")

        let omcli = payload.dictionaryPayload["omcli"] as? [String: Any] ?? [:]
        let params = omcli["params"] as? [String: Any] ?? [:]
        pendingAlarmSound = params["sound"] as? String
        pendingAlarmMessage = params["message"] as? String

        let uuid = UUID()
        activeCallUUID = uuid

        let update = CXCallUpdate()
        update.localizedCallerName = pendingAlarmMessage ?? "Alarm"
        update.hasVideo = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false

        // MUST call reportNewIncomingCall synchronously — Apple kills the app otherwise
        provider?.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error {
                print("CallService: reportNewIncomingCall failed: \(error)")
            } else {
                print("CallService: reportNewIncomingCall succeeded")
            }
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("CallService: VoIP push token invalidated")
    }

    // MARK: - CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        activeCallUUID = nil
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("CallService: call answered")
        onAlarmAnswer?(pendingAlarmSound, pendingAlarmMessage)
        pendingAlarmSound = nil
        pendingAlarmMessage = nil
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("CallService: call ended")
        onAlarmDecline?()
        activeCallUUID = nil
        pendingAlarmSound = nil
        pendingAlarmMessage = nil
        action.fulfill()
    }
}
