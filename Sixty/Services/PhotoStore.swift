import Foundation
import ImageIO
import UIKit
import SixtyCore

/// Progress photos live as JPEG files in Documents/Photos, referenced from
/// day entries by file name. Saved at most 1600 px on the long side at 80%
/// quality, which keeps a 60-day set to a few tens of megabytes.
enum PhotoStore {
    enum PhotoError: Error { case encoding }

    static let maxDimension: CGFloat = 1600
    static let quality: CGFloat = 0.8

    static var directory: URL {
        URL.documentsDirectory.appending(path: "Photos", directoryHint: .isDirectory)
    }

    static func url(for filename: String) -> URL {
        directory.appending(path: filename, directoryHint: .notDirectory)
    }

    /// Resizes, encodes and writes the photo; returns its file name,
    /// e.g. "2026-10-13-1A2B3C4D.jpg". Call off the main thread.
    static func save(_ image: UIImage, day: DayKey) throws -> String {
        let resized = resized(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: quality) else { throw PhotoError.encoding }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(day.rawValue)-\(UUID().uuidString.prefix(8)).jpg"
        try data.write(to: url(for: filename), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return filename
    }

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
        cache.removeAllObjects()
    }

    /// A downsampled image for display, cached. Nil if the file is missing.
    static func image(_ filename: String?, maxPixel: CGFloat = 1200) async -> UIImage? {
        guard let filename else { return nil }
        let key = "\(filename)@\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let url = url(for: filename)
        let image = await Task.detached(priority: .userInitiated) {
            downsample(url, maxPixel: maxPixel)
        }.value
        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    /// Total size of all saved photos in bytes, for Settings.
    static func totalBytes() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { total, url in
            total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    // MARK: Private

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 60
        return cache
    }()

    /// Redraws at scale 1, which also bakes in the orientation, so the JPEG
    /// is always upright.
    static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let factor = min(1, maxDimension / max(pixelWidth, pixelHeight))
        let target = CGSize(width: (pixelWidth * factor).rounded(), height: (pixelHeight * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func downsample(_ url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: image)
    }
}
