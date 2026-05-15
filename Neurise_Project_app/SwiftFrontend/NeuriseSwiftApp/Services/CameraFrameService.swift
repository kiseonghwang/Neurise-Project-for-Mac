import AVFoundation
import AppKit
import Combine

final class CameraFrameService: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var latestFrame: NSImage?

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "neurise.camera.queue")
    private let context = CIContext()

    func configure() {
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)

        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
    }

    func start() {
        guard !session.isRunning else { return }
        queue.async { [session] in
            session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        queue.async { [session] in
            session.stopRunning()
        }
    }
}

extension CameraFrameService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )

        DispatchQueue.main.async {
            self.latestFrame = image
        }
    }
}
