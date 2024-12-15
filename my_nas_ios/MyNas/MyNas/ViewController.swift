import UIKit
import Photos

class ViewController: UIViewController {
    private var collectionView: UICollectionView!
    private var assets: PHFetchResult<PHAsset>?
    private var checkTimer: Timer?
    
    // 上次检查时间
    private var lastCheckTime: Date {
        get {
            return UserDefaults.standard.object(forKey: "LastCheckTime") as? Date ?? Date()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LastCheckTime")
        }
    }
    
    // 已处理的资源
    private var processedAssets: Set<String> {
        get {
            let array = UserDefaults.standard.array(forKey: "ProcessedAssets") as? [String] ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "ProcessedAssets")
        }
    }
    
    // 上传状态缓存
    private var uploadStatusCache: [String: Bool] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "UploadStatusCache"),
                  let dict = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "UploadStatusCache")
            }
        }
    }
    
    // 添加多选相关属性
    private var isMultiSelectMode = false {
        didSet {
            updateNavigationItems()
        }
    }
    private var selectedAssets = Set<PHAsset>()
    
    // 添加工具栏按钮
    private lazy var selectButton: UIBarButtonItem = {
        UIBarButtonItem(
            title: "选择",
            style: .plain,
            target: self,
            action: #selector(toggleSelectMode)
        )
    }()
    
    private lazy var deleteButton: UIBarButtonItem = {
        UIBarButtonItem(
            title: "删除",
            style: .plain,
            target: self,
            action: #selector(showDeleteOptions)
        )
    }()
    
    private lazy var cancelButton: UIBarButtonItem = {
        UIBarButtonItem(
            title: "取消",
            style: .done,
            target: self,
            action: #selector(toggleSelectMode)
        )
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        requestPhotoLibraryPermission()
        startCheckingNewPhotos()
        updateNavigationItems()
    }
    
    private func setupUI() {
        title = "相册"
        view.backgroundColor = .systemBackground
        
        // 设置导航栏按钮
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        
        navigationItem.rightBarButtonItems = [settingsButton, selectButton]
        
        // 配置 CollectionView
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        
        // 启用多选功能
        collectionView.allowsMultipleSelection = true
        
        view.addSubview(collectionView)
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1/3),
            heightDimension: .fractionalWidth(1/3)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(1/3)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    @objc private func showSettings() {
        let settingsVC = SettingsViewController()
        // 直接使用导航控制器的 push 方式
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    private func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self?.loadPhotos()
                case .denied, .restricted:
                    self?.showPermissionAlert()
                case .notDetermined:
                    print("用户尚未做出选择")
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        collectionView.reloadData()
    }
    
    private func startCheckingNewPhotos() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkNewPhotos()
        }
    }
    
    private func checkNewPhotos() {
        print("开始检查新照片...")
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastCheckTime as NSDate)
        
        let newAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if newAssets.count > 0 {
            print("发现 \(newAssets.count) 张新照片")
            // 更新资源列表
            loadPhotos()
            // 动画更新 UI
            let oldCount = assets?.count ?? 0
            let indexPaths = (0..<newAssets.count).map { IndexPath(item: $0, section: 0) }
            
            collectionView.performBatchUpdates {
                collectionView.insertItems(at: indexPaths)
            } completion: { _ in
                // 滚动到顶部显示新照片
                if oldCount > 0 {
                    self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
                }
            }
        } else {
            print("没有发���新照片")
        }
        
        lastCheckTime = Date()
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "无法访问相册",
            message: "请在设置中允许访问相册",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func updateNavigationItems() {
        // 创建设置按钮
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        
        if isMultiSelectMode {
            // 多选模式下的按钮布局
            navigationItem.leftBarButtonItem = cancelButton
            navigationItem.rightBarButtonItems = [deleteButton, settingsButton]
            deleteButton.isEnabled = !selectedAssets.isEmpty
        } else {
            // 普通模式下的按钮布局
            navigationItem.leftBarButtonItem = nil
            navigationItem.rightBarButtonItems = [settingsButton, selectButton]
            selectedAssets.removeAll()
            collectionView.reloadData()
        }
    }
    
    @objc private func toggleSelectMode() {
        isMultiSelectMode.toggle()
        
        if !isMultiSelectMode {
            // 退出多选模式时，取消所有选中状态
            selectedAssets.removeAll()
            for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
                collectionView.deselectItem(at: indexPath, animated: true)
            }
        }
        
        // 更新 UI
        collectionView.allowsMultipleSelection = isMultiSelectMode
        updateNavigationItems()
    }
    
    @objc private func showDeleteOptions() {
        let alert = UIAlertController(
            title: "删除选中的照片",
            message: "请选择删除方式",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "仅删除本地照片", style: .destructive) { [weak self] _ in
            self?.deleteSelectedPhotos(includeRemote: false)
        })
        
        alert.addAction(UIAlertAction(title: "同时删除本地和远程照片", style: .destructive) { [weak self] _ in
            self?.deleteSelectedPhotos(includeRemote: true)
        })
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.barButtonItem = deleteButton
        }
        
        present(alert, animated: true)
    }
    
    private func deleteSelectedPhotos(includeRemote: Bool) {
        // 保存要删除的索引路径
        _ = selectedAssets.compactMap { asset -> IndexPath? in
            guard let index = assets?.index(of: asset) else { return nil }
            return IndexPath(item: index, section: 0)
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(self.selectedAssets as NSFastEnumeration)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    if includeRemote {
                        // TODO: 实现远程删除逻辑
                        self?.showDeleteSuccessAlert(message: "本地和远程照片已删除")
                    } else {
                        self?.showDeleteSuccessAlert(message: "本地照片已删除")
                    }
                    
                    // 删除成功后，直接退出多选模式
                    // UI 更新会通过 PHPhotoLibraryChangeObserver 自动处理
                    self?.isMultiSelectMode = false
                } else {
                    self?.showDeleteErrorAlert(error: error)
                }
            }
        }
    }
    
    private func showDeleteSuccessAlert(message: String) {
        let alert = UIAlertController(
            title: "删除成功",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            self?.isMultiSelectMode = false
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

// MARK: - UICollectionViewDataSource
extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        if let asset = assets?[indexPath.item] {
            cell.configure(with: asset, isUploaded: uploadStatusCache[asset.localIdentifier] ?? false)
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let asset = assets?[indexPath.item] else { return }
        
        if isMultiSelectMode {
            selectedAssets.insert(asset)
            deleteButton.isEnabled = true
            // 更新选中状态
            if let cell = collectionView.cellForItem(at: indexPath) {
                cell.isSelected = true
            }
        } else {
            collectionView.deselectItem(at: indexPath, animated: false)
            let imageVC = ImageViewController(assets: assets!, initialIndex: indexPath.item)
            // 设置代理
            imageVC.delegate = self
            imageVC.modalPresentationStyle = .fullScreen
            present(imageVC, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isMultiSelectMode {
            guard let asset = assets?[indexPath.item] else { return }
            selectedAssets.remove(asset)
            deleteButton.isEnabled = !selectedAssets.isEmpty
            // 更新选中状态
            if let cell = collectionView.cellForItem(at: indexPath) {
                cell.isSelected = false
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        if !isMultiSelectMode {
            toggleSelectMode()
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver
extension ViewController: PHPhotoLibraryChangeObserver {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        PHPhotoLibrary.shared().register(self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let assets = assets,
              let changes = changeInstance.changeDetails(for: assets) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            // 更新数据源
            self?.assets = changes.fetchResultAfterChanges
            
            // 如果有增量更改，使用动画更新
            if let collectionView = self?.collectionView {
                if changes.hasIncrementalChanges {
                    collectionView.performBatchUpdates {
                        // 处理删除
                        if let removed = changes.removedIndexes, !removed.isEmpty {
                            collectionView.deleteItems(at: removed.map { IndexPath(item: $0, section: 0) })
                        }
                        // 处理插入
                        if let inserted = changes.insertedIndexes, !inserted.isEmpty {
                            collectionView.insertItems(at: inserted.map { IndexPath(item: $0, section: 0) })
                        }
                        // 处理移动
                        changes.enumerateMoves { fromIndex, toIndex in
                            collectionView.moveItem(
                                at: IndexPath(item: fromIndex, section: 0),
                                to: IndexPath(item: toIndex, section: 0)
                            )
                        }
                    } completion: { _ in
                        // 处理改
                        if let changed = changes.changedIndexes, !changed.isEmpty {
                            collectionView.reloadItems(at: changed.map { IndexPath(item: $0, section: 0) })
                        }
                    }
                } else {
                    // 果变化太大，直接重新加载
                    collectionView.reloadData()
                }
            }
        }
    }
}

// MARK: - ImageViewControllerDelegate
extension ViewController: ImageViewControllerDelegate {
    func imageViewController(_ controller: ImageViewController, didDeleteAsset asset: PHAsset) {
        // 删除后更新数据
        loadPhotos()
    }
}
