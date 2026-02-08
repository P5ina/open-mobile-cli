import AVFoundation
import UIKit

final class CameraService: NSObject, AVCapturePhotoCaptureDelegate {
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var continuation: CheckedContinuation<[String: AnyCodable], Error>?

    var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    func requestPermissionIfNeeded() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }
    }

    func takePhoto(facing: String) async throws -> [String: AnyCodable] {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            setupAndCapture(facing: facing)
        }
    }

    private func setupAndCapture(facing: String) {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        let position: AVCaptureDevice.Position = facing == "front" ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            continuation?.resume(throwing: CameraError.deviceUnavailable)
            continuation = nil
            return
        }

        guard session.canAddInput(input) else {
            continuation?.resume(throwing: CameraError.deviceUnavailable)
            continuation = nil
            return
        }
        session.addInput(input)

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            continuation?.resume(throwing: CameraError.deviceUnavailable)
            continuation = nil
            return
        }
        session.addOutput(output)

        captureSession = session
        photoOutput = output

        // Run capture on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        MainActor.assumeIsolated {
            defer {
                captureSession?.stopRunning()
                captureSession = nil
                photoOutput = nil
            }

            if let error {
                continuation?.resume(throwing: error)
                continuation = nil
                return
            }

            guard let data = photo.fileDataRepresentation() else {
                continuation?.resume(throwing: CameraError.captureError)
                continuation = nil
                return
            }

            let base64 = data.base64EncodedString()
            let result: [String: AnyCodable] = [
                "base64": AnyCodable(base64),
                "format": AnyCodable("jpeg"),
            ]
            continuation?.resume(returning: result)
            continuation = nil
        }
    }
}

enum CameraError: LocalizedError {
    case notAuthorized
    case deviceUnavailable
    case captureError

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Camera access not authorized"
        case .deviceUnavailable: return "Camera device unavailable"
        case .captureError: return "Failed to capture photo"
        }
    }
}
