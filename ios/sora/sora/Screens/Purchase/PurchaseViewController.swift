import UIKit
import StoreKit

class PurchaseViewController: UIViewController {
    private let storeManager = StoreManager.shared

    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        return scroll
    }()

    private lazy var contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        return stack
    }()

    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Get Credits"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Purchase credits to create stunning AI-generated videos with Sora Engine"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var productCard: UIView = {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 2
        card.layer.borderColor = UIColor.systemIndigo.cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        card.layer.shadowOpacity = 0.1
        return card
    }()

    private lazy var productStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return stack
    }()

    private lazy var productTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Starter Pack"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private lazy var creditsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "1,000 Credits"
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .systemIndigo
        label.textAlignment = .center
        return label
    }()

    private lazy var priceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Loading..."
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private lazy var estimatesLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Estimated videos:\n• 10x Sora-2 5s videos\n• 6x Sora-2 8s videos\n• 3x Sora-2 Pro 5s videos\n• 2x Sora-2 Pro 8s videos"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var purchaseButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Purchase", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemIndigo
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(purchaseButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        observeStoreManager()
        loadProducts()
    }

    private func setupUI() {
        title = "Purchase Credits"
        view.backgroundColor = .systemGroupedBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        productCard.addSubview(productStackView)

        contentStackView.addArrangedSubview(headerLabel)
        contentStackView.addArrangedSubview(descriptionLabel)
        contentStackView.addArrangedSubview(productCard)

        productStackView.addArrangedSubview(productTitleLabel)
        productStackView.addArrangedSubview(creditsLabel)
        productStackView.addArrangedSubview(priceLabel)
        productStackView.addArrangedSubview(estimatesLabel)
        productStackView.addArrangedSubview(purchaseButton)

        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            productStackView.topAnchor.constraint(equalTo: productCard.topAnchor),
            productStackView.leadingAnchor.constraint(equalTo: productCard.leadingAnchor),
            productStackView.trailingAnchor.constraint(equalTo: productCard.trailingAnchor),
            productStackView.bottomAnchor.constraint(equalTo: productCard.bottomAnchor),

            purchaseButton.heightAnchor.constraint(equalToConstant: 50),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func observeStoreManager() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStoreUpdate),
            name: NSNotification.Name("StoreManagerDidUpdate"),
            object: nil
        )
    }

    private func loadProducts() {
        Task {
            await storeManager.loadProducts()
            updateProductUI()
        }
    }

    private func updateProductUI() {
        guard let product = storeManager.products.first else {
            priceLabel.text = "Product unavailable"
            purchaseButton.isEnabled = false
            return
        }

        priceLabel.text = product.displayPrice
        purchaseButton.isEnabled = true
    }

    @objc private func handleStoreUpdate() {
        Task { @MainActor in
            switch storeManager.purchaseState {
            case .idle:
                loadingIndicator.stopAnimating()
                purchaseButton.isEnabled = true

            case .purchasing:
                loadingIndicator.startAnimating()
                purchaseButton.isEnabled = false

            case .success(let creditsAdded, let newBalance):
                loadingIndicator.stopAnimating()
                purchaseButton.isEnabled = true
                NotificationCenter.default.post(name: NSNotification.Name("CreditsDidUpdate"), object: nil)
                showSuccessAlert(creditsAdded: creditsAdded, newBalance: newBalance)
                storeManager.resetPurchaseState()

            case .failed(let error):
                loadingIndicator.stopAnimating()
                purchaseButton.isEnabled = true
                showErrorAlert(error: error)
                storeManager.resetPurchaseState()
            }
        }
    }

    @objc private func purchaseButtonTapped() {
        guard let product = storeManager.products.first else {
            showErrorAlert(error: StoreError.invalidURL)
            return
        }

        Task {
            await storeManager.purchase(product)
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func showSuccessAlert(creditsAdded: Int64, newBalance: Int64) {
        let alert = UIAlertController(
            title: "Purchase Successful",
            message: "Added \(creditsAdded) credits to your account. New balance: \(newBalance) credits",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })

        present(alert, animated: true)
    }

    private func showErrorAlert(error: Error) {
        let alert = UIAlertController(
            title: "Purchase Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        present(alert, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
