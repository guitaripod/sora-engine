import UIKit

final class HomeViewController: UIViewController {
    private let viewModel: HomeViewModel

    private enum Section {
        case main
    }

    private lazy var collectionView: UICollectionView = {
        let layout = createLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.register(VideoCell.self, forCellWithReuseIdentifier: VideoCell.reuseIdentifier)
        return collectionView
    }()

    private lazy var dataSource: UICollectionViewDiffableDataSource<Section, Video> = {
        UICollectionViewDiffableDataSource<Section, Video>(collectionView: collectionView) { collectionView, indexPath, video in
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: VideoCell.reuseIdentifier,
                for: indexPath
            ) as? VideoCell else {
                return UICollectionViewCell()
            }

            cell.configure(with: video)
            return cell
        }
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return refresh
    }()

    private lazy var creditsTitleView: UIView = {
        let container = UIView()

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: "creditcard.fill"))
        iconView.tintColor = .systemIndigo
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let creditsLabel = UILabel()
        creditsLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        creditsLabel.textColor = .label
        creditsLabel.translatesAutoresizingMaskIntoConstraints = false
        self.creditsLabel = creditsLabel

        stackView.addArrangedSubviews(iconView, creditsLabel)
        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }()

    private var creditsLabel: UILabel!

    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No videos yet.\nTap 'Create Video' to get started!"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private lazy var skeletonView: UIView = {
        let container = UIView()
        container.backgroundColor = .systemGroupedBackground
        container.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        for _ in 0..<3 {
            let skeletonCell = createSkeletonCell()
            stackView.addArrangedSubview(skeletonCell)
        }

        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])

        return container
    }()

    private func createSkeletonCell() -> UIView {
        let cell = UIView()
        cell.backgroundColor = .systemGray6
        cell.layer.cornerRadius = 16
        cell.clipsToBounds = true
        cell.translatesAutoresizingMaskIntoConstraints = false

        let shimmerView = UIView()
        shimmerView.backgroundColor = .systemGray5
        shimmerView.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(shimmerView)

        NSLayoutConstraint.activate([
            cell.heightAnchor.constraint(equalTo: cell.widthAnchor, multiplier: 9.0 / 16.0),
            shimmerView.topAnchor.constraint(equalTo: cell.topAnchor),
            shimmerView.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            shimmerView.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            shimmerView.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
        ])

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.5
        animation.duration = 1.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        shimmerView.layer.add(animation, forKey: "shimmer")

        return cell
    }

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        bindViewModel()

        Task {
            await viewModel.loadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        Task {
            await viewModel.refreshData()
        }
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground

        view.addSubviews(collectionView, emptyStateLabel, skeletonView)
        collectionView.refreshControl = refreshControl
        collectionView.alpha = 0

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),

            skeletonView.topAnchor.constraint(equalTo: view.topAnchor),
            skeletonView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            skeletonView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            skeletonView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupNavigationBar() {
        title = "Sora Engine"
        navigationController?.navigationBar.prefersLargeTitles = true

        let createButton = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(createButtonTapped)
        )
        createButton.tintColor = .systemIndigo

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: creditsTitleView)
        navigationItem.rightBarButtonItem = createButton
    }

    private func bindViewModel() {
        observeViewModel()
    }

    private func observeViewModel() {
        withObservationTracking {
            _ = viewModel.credits
            _ = viewModel.videos
            _ = viewModel.hasCompletedInitialLoad
            _ = viewModel.isLoading
            _ = viewModel.thumbnailReadyVideoId
        } onChange: {
            Task { @MainActor [weak self] in
                self?.updateUI()
                self?.observeViewModel()
            }
        }
    }

    private func updateUI() {
        creditsLabel.text = "\(viewModel.credits)"

        updateSnapshot(with: viewModel.videos)
        emptyStateLabel.isHidden = !viewModel.hasCompletedInitialLoad || !viewModel.videos.isEmpty

        if !viewModel.isLoading {
            refreshControl.endRefreshing()

            if skeletonView.superview != nil {
                UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut) {
                    self.skeletonView.alpha = 0
                    self.collectionView.alpha = 1
                } completion: { _ in
                    self.skeletonView.removeFromSuperview()
                }
            }
        }

        if let videoId = viewModel.thumbnailReadyVideoId {
            reloadCell(for: videoId)
        }
    }

    private func updateSnapshot(with videos: [Video]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Video>()
        snapshot.appendSections([.main])
        snapshot.appendItems(videos)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func reloadCell(for videoId: String) {
        guard let video = viewModel.videos.first(where: { $0.id == videoId }) else { return }

        var snapshot = dataSource.snapshot()
        snapshot.reloadItems([video])
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(9.0 / 16.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(9.0 / 16.0)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)

        return UICollectionViewCompositionalLayout(section: section)
    }

    @objc private func createButtonTapped() {
        viewModel.createVideoTapped()
    }

    @objc private func handleRefresh() {
        Task {
            await viewModel.refreshData()
        }
    }

    @objc private func signOutTapped() {
        let alert = UIAlertController(
            title: "Sign Out",
            message: "Are you sure you want to sign out?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
            self?.viewModel.signOutTapped()
        })

        present(alert, animated: true)
    }
}

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let video = dataSource.itemIdentifier(for: indexPath) else { return }
        viewModel.videoTapped(video)
    }
}
