@preconcurrency import AVFoundation
import UIKit

/// Runs the capture session for the progress-photo camera. Session work
/// happens on a private queue; published state is on the main actor.
@MainActor
final class CameraModel: NSObject, ObservableObject {
    enum Status: Equatable {
        case starting, running, denied, unavailable, failed
    }

    @Published private(set) var status: Status = .starting
    @Published private(set) var position: AVCaptureDevice.Position
    @Published private(set) var isCapturing = false
    /// The shot waiting for Retake / Use.
    @Published var captured: UIImage?

    nonisolated let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "uk.co.timbrazier.sixty.camera")
    private var input: AVCaptureDeviceInput?

    init(position: AVCaptureDevice.Position) {
        self.position = position
        super.init()
    }

    static var isAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                status = .denied
                return
            }
        default:
            status = .denied
            return
        }
        // Fall back to the other lens if the saved one isn't there.
        guard let device = Self.device(at: position) ?? Self.device(at: position == .back ? .front : .back) else {
            status = .unavailable
            return
        }
        await use(device)
        status = input == nil ? .failed : .running
    }

    func stop() {
        let session = session
        queue.async { session.stopRunning() }
    }

    /// Switches between the front and back lenses.
    func flip() async {
        let next: AVCaptureDevice.Position = position == .back ? .front : .back
        guard let device = Self.device(at: next) else { return }
        await use(device)
    }

    func capture() {
        guard status == .running, !isCapturing, captured == nil else { return }
        isCapturing = true
        let output = output
        let settings = AVCapturePhotoSettings()
        queue.async { output.capturePhoto(with: settings, delegate: self) }
    }

    // MARK: Private

    private func use(_ device: AVCaptureDevice) async {
        let session = session, output = output, old = input
        let installed: AVCaptureDeviceInput? = await withCheckedContinuation { continuation in
            queue.async {
                let input = Self.install(device, in: session, output: output, replacing: old)
                if !session.isRunning { session.startRunning() }
                continuation.resume(returning: input)
            }
        }
        if let installed {
            input = installed
            position = device.position
        }
    }

    nonisolated private static func device(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    /// Swaps the session's input for `device`. Photos are portrait, and
    /// front-camera photos are mirrored to match the preview, so the Day 1
    /// ghost lines up whichever lens took it.
    nonisolated private static func install(_ device: AVCaptureDevice,
                                            in session: AVCaptureSession,
                                            output: AVCapturePhotoOutput,
                                            replacing old: AVCaptureDeviceInput?) -> AVCaptureDeviceInput? {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
        if let old { session.removeInput(old) }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            if let old, session.canAddInput(old) { session.addInput(old) }
            return nil
        }
        session.addInput(input)
        if !session.outputs.contains(output), session.canAddOutput(output) {
            session.addOutput(output)
        }
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = device.position == .front
            }
        }
        return input
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor in
            self.isCapturing = false
            if let image { self.captured = image }
        }
    }
}
