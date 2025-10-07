import Foundation
import Combine

final class CreateVideoViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var selectedModel: String = "sora-2"
    @Published var selectedDuration: Int = 4
    @Published var estimatedCost: Int = 0
    @Published var currentBalance: Int = 0
    @Published var isEstimating: Bool = false
    @Published var isCreating: Bool = false
    @Published var errorMessage: String?
    @Published var canCreate: Bool = false

    private let videoService: VideoServiceProtocol
    private let creditService: CreditServiceProtocol
    private weak var coordinator: AppCoordinator?
    private var estimateTask: Task<Void, Never>?

    let models = ["sora-2", "sora-2-pro"]
    let durations = [4, 8, 12]

    init(
        coordinator: AppCoordinator,
        videoService: VideoServiceProtocol = VideoService.shared,
        creditService: CreditServiceProtocol = CreditService.shared
    ) {
        self.coordinator = coordinator
        self.videoService = videoService
        self.creditService = creditService

        Task {
            await loadBalance()
            await updateEstimate()
        }
    }

    @MainActor
    func promptChanged(_ text: String) {
        prompt = text
        canCreate = text.isValidPrompt
    }

    @MainActor
    func modelChanged(_ model: String) {
        selectedModel = model
        Task {
            await updateEstimate()
        }
    }

    @MainActor
    func durationChanged(_ duration: Int) {
        selectedDuration = duration
        Task {
            await updateEstimate()
        }
    }

    @MainActor
    func createVideo() async {
        guard prompt.isValidPrompt else {
            errorMessage = "Please enter a valid prompt"
            return
        }

        guard estimatedCost <= currentBalance else {
            errorMessage = "Insufficient credits. You need \(estimatedCost) credits but have \(currentBalance)."
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            _ = try await videoService.createVideo(
                model: selectedModel,
                prompt: prompt,
                size: Constants.Video.defaultSize,
                seconds: selectedDuration
            )

            coordinator?.dismissCreateVideo()
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }

    @MainActor
    private func loadBalance() async {
        do {
            currentBalance = try await creditService.getBalance()
        } catch {
        }
    }

    @MainActor
    private func updateEstimate() async {
        estimateTask?.cancel()

        estimateTask = Task {
            isEstimating = true

            do {
                try await Task.sleep(nanoseconds: 300_000_000)

                guard !Task.isCancelled else { return }

                let response = try await videoService.estimateCost(
                    model: selectedModel,
                    size: Constants.Video.defaultSize,
                    seconds: selectedDuration
                )

                estimatedCost = response.creditsCost
                currentBalance = response.currentBalance
            } catch {
            }

            isEstimating = false
        }
    }

    deinit {
        estimateTask?.cancel()
    }
}
