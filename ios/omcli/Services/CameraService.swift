import AVFoundation
import UIKit

@Observable
final class CameraService {
    var isShowingPreview = false
    private(set) var previewSession: AVCaptureSession?

    private var photoOutput: AVCapturePhotoOutput?
    private var captureDelegate: CaptureDelegate?
    private var previewContinuation: CheckedContinuation<[String: AnyCodable], Error>?
    private var pendingFacing: String = "back"

    var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    func requestPermissionIfNeeded() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }
    }

    // MARK: - Public API (called by CommandRouter)

    func takePhoto(facing: String) async throws -> [String: AnyCodable] {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.previewContinuation = continuation
            self.pendingFacing = facing
            setupPreviewSession(facing: facing)
            self.isShowingPreview = true
        }
    }

    // MARK: - UI Actions

    func approveCapture() {
        guard let output = photoOutput else {
            previewContinuation?.resume(throwing: CameraError.captureError)
            previewContinuation = nil
            tearDown()
            return
        }

        let delegate = CaptureDelegate { [weak self] result in
            guard let self else { return }
            self.previewContinuation?.resume(with: result)
            self.previewContinuation = nil
            self.tearDown()
        }
        self.captureDelegate = delegate

        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        output.capturePhoto(with: settings, delegate: delegate)
    }

    func cancelCapture() {
        previewContinuation?.resume(throwing: CameraError.userDeclined)
        previewContinuation = nil
        tearDown()
    }

    // MARK: - Session Setup

    private func setupPreviewSession(facing: String) {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        let position: AVCaptureDevice.Position = facing == "front" ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            previewContinuation?.resume(throwing: CameraError.deviceUnavailable)
            previewContinuation = nil
            return
        }

        guard session.canAddInput(input) else {
            previewContinuation?.resume(throwing: CameraError.deviceUnavailable)
            previewContinuation = nil
            return
        }
        session.addInput(input)

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            previewContinuation?.resume(throwing: CameraError.deviceUnavailable)
            previewContinuation = nil
            return
        }
        session.addOutput(output)

        self.previewSession = session
        self.photoOutput = output

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func tearDown() {
        isShowingPreview = false
        let session = previewSession
        previewSession = nil
        photoOutput = nil
        captureDelegate = nil
        if let session {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }
}

// MARK: - Capture Delegate

private final class CaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (Result<[String: AnyCodable], Error>) -> Void

    init(completion: @escaping (Result<[String: AnyCodable], Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let result: Result<[String: AnyCodable], Error>
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation() {
            let base64 = data.base64EncodedString()
            result = .success([
                "base64": AnyCodable(base64),
                "format": AnyCodable("jpeg"),
            ])
        } else {
            result = .failure(CameraError.captureError)
        }

        DispatchQueue.main.async {
            self.completion(result)
        }
    }
}

// MARK: - Errors

enum CameraError: LocalizedError {
    case notAuthorized
    case deviceUnavailable
    case captureError
    case userDeclined

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Camera access not authorized"
        case .deviceUnavailable: return "Camera device unavailable"
        case .captureError: return "Failed to capture photo"
        case .userDeclined: return "Photo declined by user"
        }
    }
}
