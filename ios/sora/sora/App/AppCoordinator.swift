import UIKit

final class AppCoordinator {
    private let window: UIWindow
    private var navigationController: UINavigationController?

    init(window: UIWindow) {
        self.window = window
    }

    func start() {
        if AuthService.shared.isAuthenticated {
            showHome()
        } else {
            showSignIn()
        }

        window.makeKeyAndVisible()
    }

    func showSignIn() {
        let viewModel = SignInViewModel(coordinator: self)
        let viewController = SignInViewController(viewModel: viewModel)
        window.rootViewController = viewController
    }

    func showHome() {
        let viewModel = HomeViewModel(coordinator: self)
        let viewController = HomeViewController(viewModel: viewModel)
        let nav = UINavigationController(rootViewController: viewController)
        navigationController = nav
        window.rootViewController = nav
    }

    func showCreateVideo() {
        guard let nav = navigationController else { return }

        let viewModel = CreateVideoViewModel(coordinator: self)
        let viewController = CreateVideoViewController(viewModel: viewModel)
        nav.pushViewController(viewController, animated: true)
    }

    func showVideoPlayer(video: Video) {
        guard let nav = navigationController else { return }

        let viewController = VideoPlayerViewController(video: video)
        nav.present(viewController, animated: true)
    }

    func dismissCreateVideo() {
        navigationController?.popViewController(animated: true)
    }

    func signOut() {
        AuthService.shared.signOut()
        showSignIn()
    }
}
