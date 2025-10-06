import UIKit
import AVKit

final class VideoPlayerViewController: UIViewController {
    private let video: Video
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?

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
            AppLogger.video.info("Playing from cache: \(self.video.id)")
        } else {
            guard let videoURLString = video.videoUrl,
                  let remoteURL = URL(string: videoURLString) else {
                showError("Video URL not available")
                return
            }
            videoURL = remoteURL
            AppLogger.video.info("Streaming from remote: \(videoURLString)")

            Task {
                try? await VideoCacheManager.shared.downloadVideo(videoId: video.id, from: remoteURL)
            }
        }

        player = AVPlayer(url: videoURL)

        player?.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
        player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
    }

    @objc private func playerDidFinishPlaying() {
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

        AppLogger.video.info("Playing video: \(self.video.id)")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let player = object as? AVPlayer {
                AppLogger.video.info("Player status: \(player.status.rawValue)")
                if player.status == .failed {
                    if let error = player.error {
                        AppLogger.video.error("Player error: \(error.localizedDescription)")
                        loadingIndicator.stopAnimating()
                        showError("Failed to load video: \(error.localizedDescription)")
                    }
                }
            } else if let playerItem = object as? AVPlayerItem {
                AppLogger.video.info("PlayerItem status: \(playerItem.status.rawValue)")
                if playerItem.status == .failed {
                    if let error = playerItem.error {
                        AppLogger.video.error("PlayerItem error: \(error.localizedDescription)")
                        loadingIndicator.stopAnimating()
                        showError("Failed to load video: \(error.localizedDescription)")
                    }
                } else if playerItem.status == .readyToPlay {
                    AppLogger.video.info("Player ready to play")
                    showPlayerWhenReady()
                }
            }
        }
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

    deinit {
        NotificationCenter.default.removeObserver(self)
        player?.removeObserver(self, forKeyPath: "status")
        player?.currentItem?.removeObserver(self, forKeyPath: "status")
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
