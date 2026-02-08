import AVFoundation
import SwiftUI

struct CameraPreviewView: View {
    let cameraService: CameraService

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let session = cameraService.previewSession {
                CameraPreviewLayer(session: session)
                    .ignoresSafeArea()
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 24) {
                Text("Ready to take a photo?")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 60) {
                    Button(action: { cameraService.cancelCapture() }) {
                        Text("Cancel")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Button(action: { cameraService.approveCapture() }) {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 60, height: 60)
                        }
                    }

                    // Spacer to balance the cancel button
                    Color.clear
                        .frame(width: 52, height: 1)
                }
            }
            .padding(.bottom, 48)
        }
    }
}

// MARK: - UIKit Preview Layer

private struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
