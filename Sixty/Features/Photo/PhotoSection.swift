import PhotosUI
import SwiftUI

/// The day's photo slot. Empty: tap to open the camera. Filled: the photo
/// with its time and a Retake button; long-press for Retake, Choose from
/// Library or Remove.
struct PhotoSection: View {
    let filename: String?
    let takenAt: Date?
    /// Day 1's photo, shown as a ghost in the camera.
    let ghostFilename: String?
    let isLocked: Bool
    let onPhoto: (UIImage) -> Void
    let onRemove: () -> Void

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryAfterCamera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var ghost: UIImage?
    @State private var confirmRemove = false

    var body: some View {
        Group {
            if let filename {
                filled(filename)
            } else {
                empty
            }
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            // The library can only open once the camera has gone.
            if libraryAfterCamera {
                libraryAfterCamera = false
                showLibrary = true
            }
        }) {
            CameraView(ghost: ghost, onUse: onPhoto, onLibrary: { libraryAfterCamera = true })
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onPhoto(image)
                }
                pickerItem = nil
            }
        }
        .task(id: ghostFilename) {
            ghost = await PhotoStore.image(ghostFilename, maxPixel: 1600)
        }
        .confirmationDialog("Remove this photo?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove Photo", role: .destructive, action: onRemove)
        }
    }

    // MARK: States

    private var empty: some View {
        Button(action: openCamera) {
            VStack(spacing: Tokens.Space.xs) {
                Image(systemName: "camera")
                    .font(.title3)
                Text(isLocked ? "Photo" : "Add today's photo")
                    .font(Tokens.Font.headline)
            }
            .foregroundStyle(isLocked ? Tokens.Colour.ink3 : Tokens.Colour.accent)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background {
                RoundedRectangle(cornerRadius: Tokens.Radius.photo)
                    .strokeBorder(Tokens.Colour.line2, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .contextMenu {
            if !isLocked {
                Button("Take Photo", systemImage: "camera", action: openCamera)
                Button("Choose from Library", systemImage: "photo.on.rectangle") { showLibrary = true }
            }
        }
    }

    private func filled(_ filename: String) -> some View {
        PhotoThumbnail(filename: filename)
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.photo))
            .overlay(alignment: .bottom) {
                HStack {
                    if let takenAt {
                        chip(takenAt.formatted(date: .omitted, time: .shortened))
                    }
                    Spacer()
                    if !isLocked {
                        Button(action: openCamera) { chip("Retake") }
                            .buttonStyle(.plain)
                    }
                }
                .padding(Tokens.Space.s)
            }
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.photo))
            .contextMenu {
                if !isLocked {
                    Button("Retake", systemImage: "camera", action: openCamera)
                    Button("Choose from Library", systemImage: "photo.on.rectangle") { showLibrary = true }
                    Button("Remove", systemImage: "trash", role: .destructive) { confirmRemove = true }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Progress photo")
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Font.footnoteRegular.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Tokens.Colour.ink)
            .padding(.horizontal, Tokens.Space.xs + 2)
            .padding(.vertical, Tokens.Space.xxs + 2)
            .background(Tokens.Colour.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
            .frame(minHeight: Tokens.Size.minHit)
    }

    private func openCamera() {
        // No camera (the simulator): go straight to the library.
        if CameraModel.isAvailable {
            showCamera = true
        } else {
            showLibrary = true
        }
    }
}

/// A saved photo, loaded downsampled off the main thread. Shows the hatch
/// placeholder while loading or if the file is missing.
struct PhotoThumbnail: View {
    let filename: String
    var maxPixel: CGFloat = 1200
    /// `.fill` crops to the frame; `.fit` shows the whole photo (the viewer).
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Hatch()
            }
        }
        .clipped()
        .task(id: filename) {
            image = await PhotoStore.image(filename, maxPixel: maxPixel)
        }
    }
}
