import UIKit
import Photos

class PhotoCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()
    
    private let checkmarkView: UIImageView = {
        let iv = UIImageView()
        // 使用系统提供的勾选图标
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        iv.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        iv.tintColor = .systemGreen  // 设置为绿色
        iv.backgroundColor = .white   // 白色背景提高可见度
        iv.layer.cornerRadius = 12    // 圆角效果
        iv.clipsToBounds = true
        iv.isHidden = true           // 默认隐藏
        return iv
    }()
    
    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.progressTintColor = .systemBlue
        pv.trackTintColor = .systemGray5
        pv.isHidden = true
        return pv
    }()
    
    private let selectedOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(progressView)
        contentView.addSubview(checkmarkView)
        contentView.addSubview(selectedOverlay)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        selectedOverlay.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            progressView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // 勾选图标放在右上角
            checkmarkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            checkmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkmarkView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkView.heightAnchor.constraint(equalToConstant: 24),
            
            selectedOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectedOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectedOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectedOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    override var isSelected: Bool {
        didSet {
            selectedOverlay.isHidden = !isSelected
        }
    }
    
    func configure(with asset: PHAsset, isUploaded: Bool, uploadProgress: Float?) {
        // 加载缩略图
        let size = CGSize(width: 200, height: 200)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            self?.imageView.image = image
        }
        
        // 更新上传状态指示器
        checkmarkView.isHidden = !isUploaded
        
        // 更新进度条
        if let progress = uploadProgress {
            progressView.isHidden = false
            progressView.progress = progress
            // 当有进度时隐藏勾选图标
            checkmarkView.isHidden = true
        } else {
            progressView.isHidden = true
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        checkmarkView.isHidden = true
        progressView.isHidden = true
        progressView.progress = 0
        selectedOverlay.isHidden = true
        isSelected = false
    }
} 
