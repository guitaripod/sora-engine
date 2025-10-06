import AVFoundation
import UIKit

final class VideoThumbnailGenerator {
    static let shared = VideoThumbnailGenerator()

    private let thumbnailDirectory: URL

    private init() {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        thumbnailDirectory = cachesURL.appendingPathComponent("Thumbnails", isDirectory: true)

        try? FileManager.default.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
    }

    func thumbnailURL(for videoId: String) -> URL {
        thumbnailDirectory.appendingPathComponent("\(videoId).jpg")
    }

    func hasThumbnail(for videoId: String) -> Bool {
        FileManager.default.fileExists(atPath: thumbnailURL(for: videoId).path)
    }

    func generateThumbnail(for videoURL: URL, videoId: String) async throws -> UIImage {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 1280, height: 720)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        let time = CMTime(seconds: min(0.5, CMTimeGetSeconds(duration)), preferredTimescale: 600)
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        let image = UIImage(cgImage: cgImage)

        if let jpegData = image.jpegData(compressionQuality: 0.8) {
            try jpegData.write(to: thumbnailURL(for: videoId))
        }

        return image
    }

    func loadThumbnail(for videoId: String) -> UIImage? {
        guard hasThumbnail(for: videoId) else { return nil }
        return UIImage(contentsOfFile: thumbnailURL(for: videoId).path)
    }
}
