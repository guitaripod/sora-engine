import UIKit
import AVKit

final class VideoPlayerViewController: UIViewController {
    private let video: Video
    private var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?

    init(video: Video) {
        self.video = video
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayer()
    }

    private func setupPlayer() {
        guard let videoURLString = video.videoUrl,
              let videoURL = URL(string: videoURLString) else {
            showError("Video URL not available")
            return
        }

        player = AVPlayer(url: videoURL)

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

        AppLogger.video.info("Playing video: \(self.video.id)")
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
