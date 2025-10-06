import UIKit
import Combine

final class HomeViewController: UIViewController {
    private let viewModel: HomeViewModel
    private var cancellables = Set<AnyCancellable>()

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

    private lazy var creditBalanceView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemIndigo
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Credits"
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .white.withAlphaComponent(0.8)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubviews(titleLabel, creditsLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            creditsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            creditsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            creditsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            creditsLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])

        return view
    }()

    private lazy var creditsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var createButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Create Video"
        config.image = UIImage(systemName: "plus.circle.fill")
        config.imagePadding = 8
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemIndigo

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside)
        return button
    }()

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

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground

        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.spacing = 16
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubviews(creditBalanceView, createButton)

        view.addSubviews(headerStack, collectionView, emptyStateLabel)
        collectionView.refreshControl = refreshControl

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            createButton.heightAnchor.constraint(equalToConstant: 50),

            collectionView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor)
        ])
    }

    private func setupNavigationBar() {
        title = "Sora Engine"
        navigationController?.navigationBar.prefersLargeTitles = true

        let signOutButton = UIBarButtonItem(
            title: "Sign Out",
            style: .plain,
            target: self,
            action: #selector(signOutTapped)
        )
        navigationItem.rightBarButtonItem = signOutButton
    }

    private func bindViewModel() {
        viewModel.$credits
            .receive(on: DispatchQueue.main)
            .sink { [weak self] credits in
                self?.creditsLabel.text = "\(credits)"
            }
            .store(in: &cancellables)

        viewModel.$videos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videos in
                self?.updateSnapshot(with: videos)
                self?.emptyStateLabel.isHidden = !videos.isEmpty
            }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if !isLoading {
                    self?.refreshControl.endRefreshing()
                }
            }
            .store(in: &cancellables)
    }

    private func updateSnapshot(with videos: [Video]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Video>()
        snapshot.appendSections([.main])
        snapshot.appendItems(videos)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(240)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(240)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)

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
