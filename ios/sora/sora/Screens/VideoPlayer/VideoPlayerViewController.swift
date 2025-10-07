import UIKit
import AVKit
import Combine

final class VideoPlayerViewController: UIViewController {
    private let video: Video
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    private var cancellables = Set<AnyCancellable>()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    init(video: Video) {
        self.video = video
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        loadingIndicator.startAnimating()
        setupPlayer()
    }

    private func setupPlayer() {
        let videoURL: URL

        if VideoCacheManager.shared.isCached(videoId: video.id) {
            videoURL = VideoCacheManager.shared.localURL(for: video.id)
        } else {
            guard let videoURLString = video.videoUrl,
                  let remoteURL = URL(string: videoURLString) else {
                showError("Video URL not available")
                return
            }
            videoURL = remoteURL

            Task {
                try? await VideoCacheManager.shared.downloadVideo(videoId: video.id, from: remoteURL)
            }
        }

        player = AVPlayer(url: videoURL)

        guard let player = player, let playerItem = player.currentItem else {
            showError("Failed to create player")
            return
        }

        player.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .failed, let error = player.error {
                    self.loadingIndicator.stopAnimating()
                    self.showError("Failed to load video: \(error.localizedDescription)")
                }
            }
            .store(in: &cancellables)

        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .failed, let error = playerItem.error {
                    self.loadingIndicator.stopAnimating()
                    self.showError("Failed to load video: \(error.localizedDescription)")
                } else if status == .readyToPlay {
                    self.showPlayerWhenReady()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                self?.playerDidFinishPlaying()
            }
            .store(in: &cancellables)
    }

    private func playerDidFinishPlaying() {
        player?.seek(to: .zero)
        player?.play()
    }

    private func showPlayerWhenReady() {
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.delegate = self

        playerViewController = playerVC

        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.view.frame = view.bounds
        playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerVC.didMove(toParent: self)

        player?.play()
        loadingIndicator.stopAnimating()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }
}

extension VideoPlayerViewController: AVPlayerViewControllerDelegate {
    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.dismiss(animated: true)
        }
    }
}
