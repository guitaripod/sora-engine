import UIKit

final class VideoCell: UICollectionViewCell {
    static let reuseIdentifier = "VideoCell"

    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var thumbnailView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var playIconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        let image = UIImage(systemName: "play.circle.fill", withConfiguration: config)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .white
        imageView.contentMode = .center
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.isHidden = true
        return progress
    }()

    private lazy var promptLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(containerView)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.addArrangedSubviews(promptLabel, detailsLabel)

        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        thumbnailView.addSubview(playIconView)
        thumbnailView.addSubview(statusLabel)

        mainStack.addArrangedSubviews(thumbnailView, progressView, textStack)

        containerView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),

            thumbnailView.heightAnchor.constraint(equalToConstant: 160),

            playIconView.centerXAnchor.constraint(equalTo: thumbnailView.centerXAnchor),
            playIconView.centerYAnchor.constraint(equalTo: thumbnailView.centerYAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: thumbnailView.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: thumbnailView.centerYAnchor)
        ])
    }

    func configure(with video: Video) {
        promptLabel.text = video.prompt
        detailsLabel.text = "\(video.model) • \(video.seconds)s • \(video.creditsCost) credits"

        switch video.status {
        case .completed:
            statusLabel.isHidden = true
            playIconView.isHidden = false
            progressView.isHidden = true
            thumbnailView.backgroundColor = .systemIndigo

        case .inProgress:
            statusLabel.text = "Generating... \(video.progress)%"
            statusLabel.textColor = .white
            statusLabel.isHidden = false
            playIconView.isHidden = true
            progressView.isHidden = false
            progressView.progress = Float(video.progress) / 100.0
            thumbnailView.backgroundColor = .systemBlue

        case .queued:
            statusLabel.text = "Queued"
            statusLabel.textColor = .white
            statusLabel.isHidden = false
            playIconView.isHidden = true
            progressView.isHidden = true
            thumbnailView.backgroundColor = .systemGray

        case .failed:
            statusLabel.text = "Failed"
            statusLabel.textColor = .white
            statusLabel.isHidden = false
            playIconView.isHidden = true
            progressView.isHidden = true
            thumbnailView.backgroundColor = .systemRed
        }
    }
}
