import UIKit
import Photos

protocol ImageCellDelegate: AnyObject {
    func imageCellDidTap(_ cell: ImageCell)
}

class ImageCell: UICollectionViewCell {
    weak var delegate: ImageCellDelegate?
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.minimumZoomScale = 1.0
        sv.maximumZoomScale = 3.0
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.bounces = true
        return sv
    }()
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        return iv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(scrollView)
        scrollView.frame = contentView.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        
        scrollView.addSubview(imageView)
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 添加双击手势
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        // 添加单击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)
        
        // 确保双击手势优先级高于单击
        if let doubleTapGesture = scrollView.gestureRecognizers?.first(where: { $0 is UITapGestureRecognizer }) {
            tapGesture.require(toFail: doubleTapGesture)
        }
    }
    
    func configure(with asset: PHAsset) {
        // 重置缩放
        scrollView.zoomScale = 1.0
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, _ in
            self?.imageView.image = image
            self?.updateImageViewFrame()
        }
    }
    
    private func updateImageViewFrame() {
        guard let image = imageView.image else { return }
        
        let viewSize = scrollView.bounds.size
        let imageSize = image.size
        
        let widthRatio = viewSize.width / imageSize.width
        let heightRatio = viewSize.height / imageSize.height
        let minRatio = min(widthRatio, heightRatio)
        
        let scaledWidth = imageSize.width * minRatio
        let scaledHeight = imageSize.height * minRatio
        
        imageView.frame = CGRect(
            x: (viewSize.width - scaledWidth) / 2,
            y: (viewSize.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
        
        scrollView.contentSize = viewSize
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let location = gesture.location(in: imageView)
            let rect = CGRect(
                x: location.x - (scrollView.bounds.width / 4),
                y: location.y - (scrollView.bounds.height / 4),
                width: scrollView.bounds.width / 2,
                height: scrollView.bounds.height / 2
            )
            scrollView.zoom(to: rect, animated: true)
        }
    }
    
    @objc private func handleTap() {
        delegate?.imageCellDidTap(self)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        scrollView.zoomScale = 1.0
    }
}

// MARK: - UIScrollViewDelegate
extension ImageCell: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        
        imageView.center = CGPoint(
            x: scrollView.contentSize.width * 0.5 + offsetX,
            y: scrollView.contentSize.height * 0.5 + offsetY
        )
    }
}
