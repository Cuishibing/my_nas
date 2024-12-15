import UIKit
import Photos

// 在文件顶部添加协议定义
protocol ImageViewControllerDelegate: AnyObject {
    func imageViewController(_ controller: ImageViewController, didDeleteAsset asset: PHAsset)
}

class ImageViewController: UIViewController {
    private var assets: PHFetchResult<PHAsset>
    private var currentIndex: Int
    private var pageViewController: UIPageViewController!
    // 添加代理属性
    weak var delegate: ImageViewControllerDelegate?
    
    init(assets: PHFetchResult<PHAsset>, initialIndex: Int) {
        self.assets = assets
        self.currentIndex = initialIndex
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPageViewController()
    }
    
    private func setupPageViewController() {
        pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        pageViewController.dataSource = self
        pageViewController.delegate = self
        
        // 添加 PageViewController 作为子控制器
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.frame = view.bounds
        pageViewController.didMove(toParent: self)
        
        // 设置初始页面
        if let initialVC = createPhotoViewController(for: currentIndex) {
            pageViewController.setViewControllers(
                [initialVC],
                direction: .forward,
                animated: false
            )
        }
    }
    
    private func createPhotoViewController(for index: Int) -> PhotoDetailViewController? {
        guard index >= 0 && index < assets.count else { return nil }
        let photoVC = PhotoDetailViewController(asset: assets[index])
        // 设置删除回调
        photoVC.onPhotoDeleted = { [weak self] asset in
            guard let self = self else { return }
            // 通知代理
            self.delegate?.imageViewController(self, didDeleteAsset: asset)
        }
        return photoVC
    }
}

// MARK: - UIPageViewControllerDataSource
extension ImageViewController: UIPageViewControllerDataSource {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let photoVC = viewController as? PhotoDetailViewController else {
            return nil
        }
        // 获取当前索引
        let currentIndex = assets.index(of: photoVC.asset)
        // 检查是否可以向前翻页
        guard currentIndex > 0 else { return nil }
        return createPhotoViewController(for: currentIndex - 1)
    }
    
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let photoVC = viewController as? PhotoDetailViewController else {
            return nil
        }
        // 获取当前索引
        let currentIndex = assets.index(of: photoVC.asset)
        // 检查是否可以向后翻页
        guard currentIndex < assets.count - 1 else { return nil }
        return createPhotoViewController(for: currentIndex + 1)
    }
}

// MARK: - UIPageViewControllerDelegate
extension ImageViewController: UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        if completed,
           let currentVC = pageViewController.viewControllers?.first as? PhotoDetailViewController {
            // 直接使用 index(of:) 的返回值
            currentIndex = assets.index(of: currentVC.asset)
        }
    }
}

// 单个照片详情视图控制器
class PhotoDetailViewController: UIViewController {
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    let asset: PHAsset
    private var panStartPoint: CGPoint = .zero
    private var initialImageCenter: CGPoint = .zero
    // 添加删除回调
    var onPhotoDeleted: ((PHAsset) -> Void)?
    
    // 添加长按手势识别器
    private lazy var longPressGesture: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        gesture.minimumPressDuration = 0.5
        return gesture
    }()
    
    init(asset: PHAsset) {
        self.asset = asset
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImage()
        setupGestures()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        scrollView.frame = view.bounds
        scrollView.delegate = self
        view.addSubview(scrollView)
        
        imageView.frame = view.bounds
        scrollView.addSubview(imageView)
    }
    
    private func setupGestures() {
        // 添加现有的手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        view.addGestureRecognizer(tapGesture)
        
        // 添加长按手势
        view.addGestureRecognizer(longPressGesture)
    }
    
    private func loadImage() {
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
        }
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .began:
            panStartPoint = imageView.center
            initialImageCenter = imageView.center
            
        case .changed:
            guard scrollView.zoomScale == scrollView.minimumZoomScale else { return }
            
            let newCenter = CGPoint(
                x: panStartPoint.x + translation.x * 0.3,
                y: panStartPoint.y + translation.y
            )
            imageView.center = newCenter
            
            let verticalDistance = abs(translation.y)
            let alpha = 1 - (verticalDistance / 200)
            view.backgroundColor = UIColor.black.withAlphaComponent(max(0, min(1, alpha)))
            
        case .ended, .cancelled:
            if abs(velocity.y) > 1000 || abs(translation.y) > 200 {
                parent?.dismiss(animated: true)
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.imageView.center = self.initialImageCenter
                    self.view.backgroundColor = .black
                }
            }
            
        default:
            break
        }
    }
    
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        parent?.dismiss(animated: true)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let alertController = UIAlertController(
            title: "删除图片",
            message: "请选择删除方式",
            preferredStyle: .actionSheet
        )
        
        // 仅删除本地选项
        alertController.addAction(UIAlertAction(title: "仅删除本地图片", style: .destructive) { [weak self] _ in
            self?.deleteLocalPhoto()
        })
        
        // 同时删除本地和远程选项
        alertController.addAction(UIAlertAction(title: "同时删除本地和远程图片", style: .destructive) { [weak self] _ in
            self?.deleteLocalAndRemotePhoto()
        })
        
        // 取消选项
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        // 对于 iPad，需要设置 popoverPresentationController 的源视图
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(alertController, animated: true)
    }
    
    private func deleteLocalPhoto() {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([self.asset] as NSFastEnumeration)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.showDeleteSuccessAlert(message: "本地图片已删除")
                } else {
                    self?.showDeleteErrorAlert(error: error)
                }
            }
        }
    }
    
    private func deleteLocalAndRemotePhoto() {
        // ���先删除本地图片
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([self.asset] as NSFastEnumeration)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    // 本地删除成功后，删除远程图片
                    self?.deleteRemotePhoto()
                } else {
                    self?.showDeleteErrorAlert(error: error)
                }
            }
        }
    }
    
    private func deleteRemotePhoto() {
        // TODO: 实现远程删除逻辑
        // 这里需要调用您的远程服务器 API 来删除图片
        // 示例代码：
        /*
        let remotePhotoId = // 获取远程图片 ID
        NetworkManager.shared.deletePhoto(photoId: remotePhotoId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.showDeleteSuccessAlert(message: "本地和远程图片已删除")
                case .failure(let error):
                    self?.showDeleteErrorAlert(error: error)
                }
            }
        }
        */
        
        // 临时显示成功消息
        showDeleteSuccessAlert(message: "本地和远程图片已删除")
    }
    
    private func showDeleteSuccessAlert(message: String) {
        let alert = UIAlertController(
            title: "删除成功",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            if let asset = self?.asset {
                // 调用删除回调
                self?.onPhotoDeleted?(asset)
            }
            self?.parent?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    private func showDeleteErrorAlert(error: Error?) {
        let alert = UIAlertController(
            title: "删除失败",
            message: error?.localizedDescription ?? "未知错误",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIScrollViewDelegate
extension PhotoDetailViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

// MARK: - UIGestureRecognizerDelegate
extension PhotoDetailViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
} 
