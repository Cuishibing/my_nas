import UIKit
import Photos

class PhotoCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()
    
    private let uploadedIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGreen
        view.isHidden = true
        view.layer.cornerRadius = 10
        return view
    }()
    
    private let checkmarkImageView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "checkmark")
        view.tintColor = .white
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private let selectionIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        view.isHidden = true
        view.layer.cornerRadius = 12
        return view
    }()
    
    private let selectionCheckmark: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "checkmark.circle.fill")
        view.tintColor = .white
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    override var isSelected: Bool {
        didSet {
            selectionIndicator.isHidden = !isSelected
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        contentView.addSubview(uploadedIndicator)
        uploadedIndicator.frame = CGRect(x: contentView.bounds.width - 25,
                                       y: contentView.bounds.height - 25,
                                       width: 20, height: 20)
        uploadedIndicator.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        
        uploadedIndicator.addSubview(checkmarkImageView)
        checkmarkImageView.frame = uploadedIndicator.bounds.insetBy(dx: 4, dy: 4)
        checkmarkImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        contentView.addSubview(selectionIndicator)
        selectionIndicator.frame = CGRect(x: contentView.bounds.width - 30,
                                        y: 5,
                                        width: 24, height: 24)
        selectionIndicator.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        
        selectionIndicator.addSubview(selectionCheckmark)
        selectionCheckmark.frame = selectionIndicator.bounds
        selectionCheckmark.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    func configure(with asset: PHAsset, isUploaded: Bool) {
        uploadedIndicator.isHidden = !isUploaded
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            self?.imageView.image = image
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        uploadedIndicator.isHidden = true
        isSelected = false
    }
} 
