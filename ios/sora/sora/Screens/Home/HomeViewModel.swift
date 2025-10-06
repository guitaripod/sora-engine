import Foundation
import Combine

final class HomeViewModel: ObservableObject {
    @Published var credits: Int = 0
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let videoService: VideoServiceProtocol
    private let creditService: CreditServiceProtocol
    private weak var coordinator: AppCoordinator?
    private var refreshTimer: Timer?

    init(
        coordinator: AppCoordinator,
        videoService: VideoServiceProtocol = VideoService.shared,
        creditService: CreditServiceProtocol = CreditService.shared
    ) {
        self.coordinator = coordinator
        self.videoService = videoService
        self.creditService = creditService
    }

    @MainActor
    func loadData() async {
        isLoading = true
        errorMessage = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadCredits()
            }
            group.addTask {
                await self.loadVideos()
            }
        }

        isLoading = false
        startAutoRefresh()
    }

    @MainActor
    func refreshData() async {
        await loadData()
    }

    @MainActor
    func createVideoTapped() {
        coordinator?.showCreateVideo()
    }

    @MainActor
    func videoTapped(_ video: Video) {
        if video.status == .completed, video.videoUrl != nil {
            coordinator?.showVideoPlayer(video: video)
        }
    }

    @MainActor
    func signOutTapped() {
        stopAutoRefresh()
        coordinator?.signOut()
    }

    @MainActor
    private func loadCredits() async {
        do {
            credits = try await creditService.getBalance()
            AppLogger.ui.info("Credits loaded: \(self.credits)")
        } catch {
            AppLogger.ui.error("Failed to load credits: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func loadVideos() async {
        do {
            let response = try await videoService.listVideos(limit: 50, offset: 0)
            videos = response.videos
            AppLogger.ui.info("Videos loaded: \(self.videos.count)")
        } catch {
            AppLogger.ui.error("Failed to load videos: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func startAutoRefresh() {
        guard hasActiveVideos else { return }

        stopAutoRefresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshActiveVideos()
            }
        }
    }

    @MainActor
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @MainActor
    private func refreshActiveVideos() async {
        let activeVideos = videos.filter { $0.status == .queued || $0.status == .inProgress }

        for video in activeVideos {
            do {
                let updated = try await videoService.getVideo(id: video.id)

                if let index = videos.firstIndex(where: { $0.id == video.id }) {
                    videos[index] = updated
                }
            } catch {
                AppLogger.ui.error("Failed to refresh video \(video.id): \(error.localizedDescription)")
            }
        }

        if !hasActiveVideos {
            stopAutoRefresh()
        }

        await loadCredits()
    }

    private var hasActiveVideos: Bool {
        videos.contains { $0.status == .queued || $0.status == .inProgress }
    }

    deinit {
        refreshTimer?.invalidate()
    }
}
