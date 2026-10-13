import AVFoundation
import AVKit
import SwiftUI

/// Full-screen progress-photo camera. Opens on the last-used lens, with
/// Day 1's photo over the viewfinder at 25% as an alignment ghost (tap to
/// hide). The shutter is bottom-centre; the volume buttons also fire it.
/// After a shot: Retake or Use.
struct CameraView: View {
    let ghost: UIImage?
    let onUse: (UIImage) -> Void
    /// Close the camera and open the photo library instead.
    let onLibrary: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("cameraPosition") private var savedPosition = "back"
    @StateObject private var camera: CameraModel
    @State private var showGhost = true

    init(ghost: UIImage?, onUse: @escaping (UIImage) -> Void, onLibrary: @escaping () -> Void) {
        self.ghost = ghost
        self.onUse = onUse
        self.onLibrary = onLibrary
        let saved = UserDefaults.standard.string(forKey: "cameraPosition")
        _camera = StateObject(wrappedValue: CameraModel(position: saved == "front" ? .front : .back))
    }

    var body: some View {
        VStack(spacing: Tokens.Space.m) {
            topBar
            Spacer(minLength: 0)
            viewfinder
            Spacer(minLength: 0)
            bottomBar
        }
        .padding(.horizontal, Tokens.Space.m)
        .padding(.vertical, Tokens.Space.s)
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .sensoryFeedback(.impact(weight: .medium), trigger: camera.isCapturing) { _, new in new }
    }

    // MARK: Parts

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: Tokens.Size.minHit, height: Tokens.Size.minHit)
            }
            .accessibilityLabel("Close")
            Spacer()
            if ghost != nil && camera.captured == nil && camera.status == .running {
                Text(showGhost ? "Day 1 ghost on · tap to hide" : "Tap to show Day 1")
                    .font(Tokens.Font.footnoteRegular)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Color.clear.frame(width: Tokens.Size.minHit, height: Tokens.Size.minHit)
        }
    }

    private var viewfinder: some View {
        ZStack {
            Color(white: 0.08)
            if let captured = camera.captured {
                Image(uiImage: captured)
                    .resizable()
                    .scaledToFill()
            } else {
                switch camera.status {
                case .running, .starting:
                    CameraPreview(session: camera.session) { camera.capture() }
                    if showGhost, let ghost {
                        Image(uiImage: ghost)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.25)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                case .denied:
                    message("Sixty needs the camera for your daily photo.",
                            action: "Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                case .unavailable, .failed:
                    message("The camera isn't available.", action: "Choose from Library", perform: chooseLibrary)
                }
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.photo))
        .contentShape(Rectangle())
        .onTapGesture {
            if ghost != nil && camera.captured == nil { showGhost.toggle() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(camera.captured == nil ? "Viewfinder" : "Photo preview")
    }

    @ViewBuilder
    private var bottomBar: some View {
        if let captured = camera.captured {
            HStack {
                Button("Retake") { camera.captured = nil }
                    .font(Tokens.Font.headline)
                    .frame(minWidth: 88, minHeight: Tokens.Size.minHit)
                Spacer()
                Button("Use Photo") {
                    onUse(captured)
                    dismiss()
                }
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Colour.accentInk)
                .padding(.horizontal, Tokens.Space.l)
                .frame(minHeight: Tokens.Size.minHit + 4)
                .background(Tokens.Colour.accent, in: Capsule())
            }
            .frame(height: 88)
        } else {
            HStack {
                roundButton("photo.on.rectangle", label: "Choose from Library", action: chooseLibrary)
                Spacer()
                Button { camera.capture() } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                        Circle().fill(.white).frame(width: 62, height: 62)
                            .scaleEffect(camera.isCapturing ? 0.85 : 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(camera.status != .running)
                .accessibilityLabel("Take photo")
                Spacer()
                roundButton("arrow.triangle.2.circlepath.camera", label: "Switch camera") {
                    Task {
                        await camera.flip()
                        savedPosition = camera.position == .front ? "front" : "back"
                    }
                }
                .disabled(camera.status != .running)
            }
            .frame(height: 88)
            .animation(.easeOut(duration: 0.12), value: camera.isCapturing)
        }
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func message(_ text: String, action: String, perform: @escaping () -> Void) -> some View {
        VStack(spacing: Tokens.Space.m) {
            Text(text)
                .font(Tokens.Font.body)
                .multilineTextAlignment(.center)
            Button(action, action: perform)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Colour.accent)
        }
        .padding(Tokens.Space.xl)
    }

    private func chooseLibrary() {
        onLibrary()
        dismiss()
    }
}

/// The live camera feed. Also turns the volume buttons into a shutter
/// (iOS 17.2 and later).
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onHardwareShutter: () -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if #available(iOS 17.2, *) {
            let coordinator = context.coordinator
            let interaction = AVCaptureEventInteraction { event in
                if event.phase == .began { coordinator.onHardwareShutter() }
            }
            view.addInteraction(interaction)
        }
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.onHardwareShutter = onHardwareShutter
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onHardwareShutter: onHardwareShutter)
    }

    final class Coordinator {
        var onHardwareShutter: () -> Void
        init(onHardwareShutter: @escaping () -> Void) { self.onHardwareShutter = onHardwareShutter }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
