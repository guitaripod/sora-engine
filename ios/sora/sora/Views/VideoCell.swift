import UIKit

final class VideoCell: UICollectionViewCell {
    static let reuseIdentifier = "VideoCell"

    private lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .systemGray5
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.8).cgColor
        ]
        layer.locations = [0.3, 1.0]
        return layer
    }()

    private lazy var playIconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .semibold)
        let image = UIImage(systemName: "play.circle.fill", withConfiguration: config)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .white
        imageView.contentMode = .center
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        imageView.alpha = 0.9
        return imageView
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.tintColor = .white
        progress.trackTintColor = .white.withAlphaComponent(0.3)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.isHidden = true
        return progress
    }()

    private lazy var textContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var promptLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.8)
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

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = thumbnailImageView.bounds
    }

    private func setupUI() {
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true

        contentView.addSubview(thumbnailImageView)
        thumbnailImageView.layer.addSublayer(gradientLayer)

        contentView.addSubview(playIconView)
        contentView.addSubview(loadingIndicator)
        contentView.addSubview(statusLabel)
        contentView.addSubview(progressView)

        textContainer.addSubview(promptLabel)
        textContainer.addSubview(detailsLabel)
        contentView.addSubview(textContainer)

        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            playIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            playIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -20),

            statusLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 12),

            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),

            textContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            textContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            promptLabel.topAnchor.constraint(equalTo: textContainer.topAnchor),
            promptLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            promptLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),

            detailsLabel.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 4),
            detailsLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            detailsLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            detailsLabel.bottomAnchor.constraint(equalTo: textContainer.bottomAnchor)
        ])
    }

    func configure(with video: Video) {
        promptLabel.text = video.prompt
        detailsLabel.text = "\(video.model) • \(video.seconds)s"

        if let thumbnail = VideoThumbnailGenerator.shared.loadThumbnail(for: video.id) {
            thumbnailImageView.image = thumbnail
            gradientLayer.isHidden = false
        } else {
            thumbnailImageView.image = nil
            gradientLayer.isHidden = true
        }

        switch video.status {
        case .completed:
            statusLabel.isHidden = true
            playIconView.isHidden = false
            progressView.isHidden = true
            loadingIndicator.stopAnimating()
            thumbnailImageView.backgroundColor = .systemIndigo
            textContainer.isHidden = false

        case .inProgress:
            statusLabel.text = "Generating \(video.progress)%"
            statusLabel.isHidden = false
            playIconView.isHidden = true
            progressView.isHidden = false
            progressView.progress = Float(video.progress) / 100.0
            loadingIndicator.startAnimating()
            thumbnailImageView.backgroundColor = .systemBlue
            textContainer.isHidden = true

        case .queued:
            statusLabel.text = "Creating your video..."
            statusLabel.isHidden = false
            playIconView.isHidden = true
            progressView.isHidden = true
            loadingIndicator.startAnimating()
            thumbnailImageView.backgroundColor = .systemGray
            textContainer.isHidden = true

        case .failed:
            statusLabel.text = "Generation failed"
            statusLabel.isHidden = false
            playIconView.isHidden = true
            progressView.isHidden = true
            loadingIndicator.stopAnimating()
            thumbnailImageView.backgroundColor = .systemRed
            textContainer.isHidden = true
        }
    }
}
