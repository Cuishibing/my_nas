import UIKit
import Photos

class PhotoCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()
    
    private let uploadStatusView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = .systemBlue
        progress.trackTintColor = .systemGray5
        progress.isHidden = true
        return progress
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
        contentView.addSubview(uploadStatusView)
        contentView.addSubview(progressView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        uploadStatusView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            uploadStatusView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            uploadStatusView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            uploadStatusView.widthAnchor.constraint(equalToConstant: 20),
            uploadStatusView.heightAnchor.constraint(equalToConstant: 20),
            
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: uploadStatusView.topAnchor, constant: -2),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }
    
    func configure(with asset: PHAsset, isUploaded: Bool, uploadProgress: Float? = nil) {
        uploadStatusView.isHidden = !isUploaded
        
        if let progress = uploadProgress {
            progressView.isHidden = false
            progressView.progress = progress
        } else {
            progressView.isHidden = true
            progressView.progress = 0
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            self?.imageView.image = image
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        uploadStatusView.isHidden = true
        progressView.isHidden = true
        progressView.progress = 0
    }
} 
