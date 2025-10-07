import UIKit
import Combine

final class CreateVideoViewController: UIViewController {
    private let viewModel: CreateVideoViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()

    private lazy var promptTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.backgroundColor = .secondarySystemGroupedBackground
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        return textView
    }()

    private lazy var promptPlaceholder: UILabel = {
        let label = UILabel()
        label.text = "Describe your video... (e.g., 'A serene beach at sunset with gentle waves')"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var characterCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var modelControl: UISegmentedControl = {
        let control = UISegmentedControl(items: viewModel.models)
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addTarget(self, action: #selector(modelChanged), for: .valueChanged)
        return control
    }()

    private lazy var durationControl: UISegmentedControl = {
        let items = viewModel.durations.map { "\($0)s" }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addTarget(self, action: #selector(durationChanged), for: .valueChanged)
        return control
    }()

    private lazy var costLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var balanceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var createButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Create Video"
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemIndigo

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    init(viewModel: CreateVideoViewModel) {
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
        setupKeyboardHandling()
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let promptSection = createSection(title: "Prompt", content: {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false

            container.addSubviews(promptTextView, promptPlaceholder, characterCountLabel)

            NSLayoutConstraint.activate([
                promptTextView.topAnchor.constraint(equalTo: container.topAnchor),
                promptTextView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                promptTextView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                promptTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

                promptPlaceholder.topAnchor.constraint(equalTo: promptTextView.topAnchor, constant: 16),
                promptPlaceholder.leadingAnchor.constraint(equalTo: promptTextView.leadingAnchor, constant: 16),
                promptPlaceholder.trailingAnchor.constraint(equalTo: promptTextView.trailingAnchor, constant: -16),

                characterCountLabel.topAnchor.constraint(equalTo: promptTextView.bottomAnchor, constant: 4),
                characterCountLabel.trailingAnchor.constraint(equalTo: promptTextView.trailingAnchor),
                characterCountLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])

            return container
        }())

        let modelSection = createSection(title: "Model", content: modelControl)
        let durationSection = createSection(title: "Duration", content: durationControl)

        let costStack = UIStackView()
        costStack.axis = .vertical
        costStack.spacing = 4
        costStack.alignment = .center
        costStack.translatesAutoresizingMaskIntoConstraints = false
        costStack.addArrangedSubviews(costLabel, balanceLabel, loadingIndicator)

        let costSection = createSection(title: "Cost", content: costStack)

        contentStack.addArrangedSubviews(
            promptSection,
            modelSection,
            durationSection,
            costSection,
            createButton
        )

        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),

            createButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func createSection(title: String, content: UIView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubviews(titleLabel, content)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            content.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func setupNavigationBar() {
        title = "Create Video"
        navigationItem.largeTitleDisplayMode = .never
    }

    private func bindViewModel() {
        viewModel.$estimatedCost
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cost in
                self?.costLabel.text = "\(cost) credits"
            }
            .store(in: &cancellables)

        viewModel.$currentBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                self?.balanceLabel.text = "Balance: \(balance) credits"
            }
            .store(in: &cancellables)

        viewModel.$isEstimating
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEstimating in
                if isEstimating {
                    self?.loadingIndicator.startAnimating()
                } else {
                    self?.loadingIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)

        viewModel.$isCreating
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isCreating in
                self?.createButton.isEnabled = !isCreating
                self?.createButton.configuration?.showsActivityIndicator = isCreating
            }
            .store(in: &cancellables)

        viewModel.$canCreate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canCreate in
                self?.createButton.isEnabled = canCreate
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)

        updateCharacterCount()
    }

    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func updateCharacterCount() {
        let count = viewModel.prompt.count
        let max = Constants.Video.maxPromptLength
        characterCountLabel.text = "\(count)/\(max)"
        characterCountLabel.textColor = count > max ? .systemRed : .secondaryLabel
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func modelChanged() {
        let model = viewModel.models[modelControl.selectedSegmentIndex]
        viewModel.modelChanged(model)
    }

    @objc private func durationChanged() {
        let duration = viewModel.durations[durationControl.selectedSegmentIndex]
        viewModel.durationChanged(duration)
    }

    @objc private func createButtonTapped() {
        Task {
            await viewModel.createVideo()
        }
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.height, right: 0)
        scrollView.contentInset = contentInset
        scrollView.scrollIndicatorInsets = contentInset
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension CreateVideoViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        promptPlaceholder.isHidden = !textView.text.isEmpty
        viewModel.promptChanged(textView.text)
        updateCharacterCount()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentText = textView.text as NSString
        let newText = currentText.replacingCharacters(in: range, with: text)
        return newText.count <= Constants.Video.maxPromptLength
    }
}
