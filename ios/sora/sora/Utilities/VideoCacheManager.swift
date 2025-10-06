import Foundation

final class VideoCacheManager {
    static let shared = VideoCacheManager()

    private let cacheDirectory: URL

    private init() {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesURL.appendingPathComponent("Videos", isDirectory: true)

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func localURL(for videoId: String) -> URL {
        cacheDirectory.appendingPathComponent("\(videoId).mp4")
    }

    func isCached(videoId: String) -> Bool {
        FileManager.default.fileExists(atPath: localURL(for: videoId).path)
    }

    func downloadVideo(videoId: String, from remoteURL: URL) async throws {
        let localURL = localURL(for: videoId)

        if isCached(videoId: videoId) {
            AppLogger.video.info("Video already cached: \(videoId)")
            return
        }

        AppLogger.video.info("Downloading video to cache: \(videoId)")

        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)

        try FileManager.default.moveItem(at: tempURL, to: localURL)

        AppLogger.video.info("Video cached successfully: \(videoId)")
    }

    func clearCache() throws {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        )

        for fileURL in fileURLs {
            try FileManager.default.removeItem(at: fileURL)
        }

        AppLogger.video.info("Video cache cleared")
    }

    func cacheSize() -> Int64 {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }

        return fileURLs.reduce(0) { total, url in
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                return total
            }
            return total + Int64(size)
        }
    }
}
