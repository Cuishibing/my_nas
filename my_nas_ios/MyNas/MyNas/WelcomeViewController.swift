import UIKit

class WelcomeViewController: UIViewController {
    
    private let pageControl: UIPageControl = {
        let control = UIPageControl()
        control.numberOfPages = 3
        control.currentPage = 0
        control.currentPageIndicatorTintColor = .systemBlue
        control.pageIndicatorTintColor = .systemGray3
        return control
    }()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.backgroundColor = .systemBackground
        return cv
    }()
    
    private let usernameContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 10
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
    private let usernameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "请输入用户名"
        tf.borderStyle = .roundedRect
        tf.textAlignment = .center
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        return tf
    }()
    
    private let startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开始使用", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 22
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        return button
    }()
    
    private let features = [
        ("cloud.fill", "远程同步", "自动将照片同步到远程服务器，随时随地访问"),
        ("photo.fill", "海量存储", "支持TB级照片存储，告别存储空间不足"),
        ("lock.fill", "安全可靠", "端到端加密，确保您的照片安全")
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // 添加日志
        let savedUsername = UserDefaults.standard.string(forKey: "Username")
        print("已保存的用户名: \(String(describing: savedUsername))")
        
        if savedUsername != nil {
            print("检测到已保存用户名，准备跳转到主页")
            navigateToMainScreen()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 配置CollectionView
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(FeatureCell.self, forCellWithReuseIdentifier: "FeatureCell")
        
        // 添加视图
        view.addSubview(collectionView)
        view.addSubview(pageControl)
        view.addSubview(usernameContainer)
        usernameContainer.addSubview(usernameTextField)
        view.addSubview(startButton)
        
        // 设置约束
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        usernameContainer.translatesAutoresizingMaskIntoConstraints = false
        usernameTextField.translatesAutoresizingMaskIntoConstraints = false
        startButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            
            pageControl.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 20),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            usernameContainer.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 40),
            usernameContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            usernameContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            usernameContainer.heightAnchor.constraint(equalToConstant: 60),
            
            usernameTextField.topAnchor.constraint(equalTo: usernameContainer.topAnchor, constant: 8),
            usernameTextField.leadingAnchor.constraint(equalTo: usernameContainer.leadingAnchor, constant: 8),
            usernameTextField.trailingAnchor.constraint(equalTo: usernameContainer.trailingAnchor, constant: -8),
            usernameTextField.bottomAnchor.constraint(equalTo: usernameContainer.bottomAnchor, constant: -8),
            
            startButton.topAnchor.constraint(equalTo: usernameContainer.bottomAnchor, constant: 40),
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            startButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
    }
    
    @objc private func startButtonTapped() {
        guard let username = usernameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !username.isEmpty else {
            showAlert(message: "请输入用户名")
            return
        }
        
        // 添加日志
        print("正在保存用户名: \(username)")
        
        // 保存用户名
        UserDefaults.standard.set(username, forKey: "Username")
        UserDefaults.standard.synchronize()
        
        // 保存一个标记表示已经完成首次设置
        UserDefaults.standard.set(true, forKey: "HasCompletedWelcome")
        UserDefaults.standard.synchronize()
        
        navigateToMainScreen()
    }
    
    private func navigateToMainScreen() {
        let viewController = ViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource
extension WelcomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return features.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeatureCell", for: indexPath) as! FeatureCell
        let feature = features[indexPath.item]
        cell.configure(iconName: feature.0, title: feature.1, description: feature.2)
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension WelcomeViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.x / scrollView.bounds.width)
        pageControl.currentPage = page
    }
}

// MARK: - FeatureCell
class FeatureCell: UICollectionViewCell {
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemBlue
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
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
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -60),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 100),
            iconImageView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40)
        ])
    }
    
    func configure(iconName: String, title: String, description: String) {
        iconImageView.image = UIImage(systemName: iconName)
        titleLabel.text = title
        descriptionLabel.text = description
    }
} 