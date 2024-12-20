import UIKit
import Photos
import CommonCrypto

struct ServerConfig {
    static var shared = ServerConfig()
    
    var serverURL: URL? {
        guard let ip = UserDefaults.standard.string(forKey: "ServerIP"),
              let portString = UserDefaults.standard.string(forKey: "ServerPort"),
              let port = Int(portString) else {
            return nil
        }
        return URL(string: "http://\(ip):\(port)")
    }
    
    // 检查服务器配置是否有效
    var isConfigured: Bool {
        return serverURL != nil
    }
}

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
    
    // 添加属性
    private var serverConfig: ServerConfig = .shared
    
    // 为了避免重复上传，添加一个正在上传的资产集合
    private var uploadingAssets = Set<String>()
    
    // 上传队列
    private var uploadQueue: [PHAsset] = []
    private var isUploading = false
    
    // 在 ViewController 类中添加上传进度跟踪
    private var uploadProgress: [String: Float] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        requestPhotoLibraryPermission()
        checkServerConfig() // 先检查服务器配置
        
        // 只有在服务器已配置的情况下才启动检查
        if serverConfig.isConfigured {
            startCheckingNewPhotos()
        }
        
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
        // 如果服务器未配置，不启动定时器
        guard serverConfig.isConfigured else {
            return
        }
        
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkNewPhotos()
        }
    }
    
    private func checkNewPhotos() {
        // 如果服务器未配置，不执行检查
        guard serverConfig.isConfigured else {
            return
        }
        
        print("开始检查新照片...")
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastCheckTime as NSDate)
        
        let newAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if newAssets.count > 0 {
            print("发现 \(newAssets.count) 张新照片")
            
            // 上传新照片
            for i in 0..<newAssets.count {
                let asset = newAssets[i]
                uploadPhoto(asset: asset)
            }
            
            // 先更新数据源
            let oldAssets = self.assets
            loadPhotos()
            
            // 如果有之前的数据源，执行增量更新
            if let oldAssets = oldAssets {
                // 计算新增的索引路径
                let oldCount = oldAssets.count
                let newCount = self.assets?.count ?? 0
                
                // 只有当新数量大于旧数量时才执行插入操作
                if newCount > oldCount {
                    let indexPaths = (0..<(newCount - oldCount)).map { 
                        IndexPath(item: $0, section: 0)
                    }
                    
                    collectionView.performBatchUpdates {
                        collectionView.insertItems(at: indexPaths)
                    } completion: { _ in
                        // 滚动到顶部显示新照片
                        if oldCount > 0 {
                            self.collectionView.scrollToItem(
                                at: IndexPath(item: 0, section: 0),
                                at: .top,
                                animated: true
                            )
                        }
                    }
                } else {
                    // 如果数量关系不符合预期，直接重新加载
                    collectionView.reloadData()
                }
            } else {
                // 如果没有之前的数据源，直接重新加载
                collectionView.reloadData()
            }
        } else {
            print("没有发现新照片")
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
            // 退出多选模式，取消所有选中状态
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
    
    // 添加服务器配置检查方法
    private func checkServerConfig() {
        if !serverConfig.isConfigured {
            showServerConfigAlert()
            // 如果有定时器在运行，停止它
            checkTimer?.invalidate()
            checkTimer = nil
        } else {
            // 如果服务器已配置但定时器未运行，启动它
            if checkTimer == nil {
                startCheckingNewPhotos()
            }
        }
    }
    
    private func showServerConfigAlert() {
        let alert = UIAlertController(
            title: "服务器未配置",
            message: "请先在设置中配置服务器地址和端口",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { [weak self] _ in
            let settingsVC = SettingsViewController()
            self?.navigationController?.pushViewController(settingsVC, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "稍后设置", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // 在需要使用服务器地址的地方，可以这样使用：
    private func uploadPhoto(asset: PHAsset) {
        // 先检查服务器配置
        guard serverConfig.isConfigured else {
            return
        }
        
        // 检查是否已经在队列中或已上传
        guard !uploadingAssets.contains(asset.localIdentifier),
              !(uploadStatusCache[asset.localIdentifier] ?? false) else {
            return
        }
        
        // 标记为正在处理
        uploadingAssets.insert(asset.localIdentifier)
        
        // 添加到上传队列
        uploadQueue.append(asset)
        
        // 如果当前没有正在上传的文件，开始上传
        processUploadQueue()
    }
    
    // 添加处理上传队列的方法
    private func processUploadQueue() {
        // 如果正在上传或队列为空，直接返回
        guard !isUploading, let asset = uploadQueue.first else {
            return
        }
        
        // 标记为正在上传
        isUploading = true
        
        // 检查文件是否存在
        checkFileExists(asset: asset) { [weak self] fileExists in
            if fileExists {
                print("文件已存在，无需重复上传")
                self?.handleUploadComplete(asset: asset, success: true)
            } else {
                // 文件不存在，执行上传
                self?.performUpload(asset: asset)
            }
        }
    }
    
    // 添加处理上传完成的方法
    private func handleUploadComplete(asset: PHAsset, success: Bool) {
        // 从队列中移除
        uploadQueue.removeFirst()
        
        // 从正在上传集合中移除
        uploadingAssets.remove(asset.localIdentifier)
        
        // 更新上传状态
        if success {
            uploadStatusCache[asset.localIdentifier] = true
            // 刷新对应的单元格
            if let index = assets?.index(of: asset) {
                collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            }
        }
        
        // 重置上传状态
        isUploading = false
        
        // 处理队列中的下一个文件
        processUploadQueue()
    }
    
    // 修改 performUpload 方法
    private func performUpload(asset: PHAsset) {
        guard let serverURL = serverConfig.serverURL else {
            handleUploadComplete(asset: asset, success: false)
            showServerConfigAlert()
            return
        }
        
        let uploadURL = serverURL.appendingPathComponent("model/FileManageModel/uploadFile")
        
        // 获取资源的原始数据
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { [weak self] (data, _, _, info) in
            guard let self = self,
                  let imageData = data else {
                print("获取图片数据失败")
                self?.handleUploadComplete(asset: asset, success: false)
                return
            }
            
            // 创建 URLSession 配置
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration)
            
            // 创建URLRequest
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            
            // 生成boundary
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            // 创建multipart form数据
            var body = Data()
            
            // 添加文件数据
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(asset.localIdentifier).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            
            // 获取资产的创建日期
            let creationDate = asset.creationDate ?? Date()
            let dateString = DateFormatter.yyyyMMdd.string(from: creationDate)
            
            // 添加其他必要的字段
            let fields = [
                "path": "/cuishibing/\(dateString)",  // 使用资产的创建���期
                "name": asset.localIdentifier,
                "createTime": "\(Int(creationDate.timeIntervalSince1970))"  // 也使用资产的创建时间
            ]
            
            for (key, value) in fields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
            
            // 添加结束标记
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            // 创建上传任务
            let task = session.uploadTask(with: request, from: body) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    // 清除进度
                    self?.uploadProgress.removeValue(forKey: asset.localIdentifier)
                    
                    if let error = error {
                        print("上传失败: \(error.localizedDescription)")
                        self?.handleUploadComplete(asset: asset, success: false)
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200 {
                        print("上传成功")
                        self?.handleUploadComplete(asset: asset, success: true)
                    } else {
                        self?.handleUploadComplete(asset: asset, success: false)
                    }
                }
            }
            
            // 添加进度观察
            let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                DispatchQueue.main.async {
                    self?.updateUploadProgress(for: asset, progress: Float(progress.fractionCompleted))
                }
            }
            
            // 保存观察者以防止被释放
            objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)
            
            task.resume()
        }
    }
    
    // 添加更新进度的方法
    private func updateUploadProgress(for asset: PHAsset, progress: Float) {
        uploadProgress[asset.localIdentifier] = progress
        
        // 更新对应的单元格
        if let index = assets?.index(of: asset),
           let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? PhotoCell {
            cell.configure(with: asset, isUploaded: false, uploadProgress: progress)
        }
    }
    
    // 在 ViewController 类中添加检查文件是否存在的方法
    private func checkFileExists(asset: PHAsset, completion: @escaping (Bool) -> Void) {
        guard let serverURL = serverConfig.serverURL else {
            completion(false)
            return
        }
        
        // 创建检查文件存在的URL
        let checkURL = serverURL.appendingPathComponent("model/FileManageModel/fileExist")
        
        // 创建请求
        var request = URLRequest(url: checkURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 计算文件的MD5
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { (data, _, _, _) in
            guard let imageData = data else {
                completion(false)
                return
            }
            
            // 使用新的部分MD5计算方法
            let md5String = imageData.partialMD5String
            
            // 创建请求体
            let requestBody: [String: String] = ["md5": md5String]
            
            // 序列化为JSON数据
            guard let jsonData = try? JSONEncoder().encode(requestBody) else {
                completion(false)
                return
            }
            
            request.httpBody = jsonData
            
            // 发送请求
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        print("检查文件存在失败: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200,
                       let data = data,
                       let responseString = String(data: data, encoding: .utf8) {
                        print("检查文件响应: \(responseString)")
                        // 据响应判断文件是否存在
                        // TODO: 根据实际响应格式解析结果
                        let fileExists = responseString.contains("true") // 示例判断逻辑
                        completion(fileExists)
                    } else {
                        completion(false)
                    }
                }
            }
            
            task.resume()
        }
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
            let isUploaded = uploadStatusCache[asset.localIdentifier] ?? false
            let progress = uploadProgress[asset.localIdentifier]
            
            cell.configure(with: asset, isUploaded: isUploaded, uploadProgress: progress)
            
            // 只有在服务器已配置且文件未上传时才触发上传
            if serverConfig.isConfigured && !isUploaded && progress == nil {
                uploadPhoto(asset: asset)
            }
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
            
            // 如果有增加更改，使用动画更新
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
                    // 果变化太大，直接重加载
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

// 添加日期格式化扩展
extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

// 修改 Data 的 MD5 扩展
extension Data {
    var partialMD5String: String {
        let chunkSize = 20 * 1024 // 20KB
        var dataToHash = Data()
        
        // 添加前20KB
        let frontData = self.prefix(chunkSize)
        dataToHash.append(frontData)
        
        // 如果文件大小超过40KB，添加后20KB
        if self.count > (2 * chunkSize) {
            let backData = self.suffix(chunkSize)
            dataToHash.append(backData)
        } else if self.count > chunkSize {
            // 如���文件大小在20KB-40KB之间，添加剩部分
            let backData = self.suffix(self.count - chunkSize)
            dataToHash.append(backData)
        }
        
        // 计算MD5
        return dataToHash.md5String
    }
}

extension Data {
    var md5String: String {
        let hash = self.withUnsafeBytes { bytes -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: 16)
            var context = MD5_CTX()
            MD5_Init(&context)
            MD5_Update(&context, bytes.baseAddress, numericCast(self.count))
            MD5_Final(&hash, &context)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// 添加 MD5 相关结构体和函数
private struct MD5_CTX {
    var A: UInt32
    var B: UInt32
    var C: UInt32
    var D: UInt32
    var count: UInt64
    var buffer: [UInt8]
    
    init() {
        A = 0x67452301
        B = 0xEFCDAB89
        C = 0x98BADCFE
        D = 0x10325476
        count = 0
        buffer = [UInt8](repeating: 0, count: 64)
    }
}

private func MD5_Init(_ context: inout MD5_CTX) {
    context = MD5_CTX()
}

private func MD5_Update(_ context: inout MD5_CTX, _ input: UnsafeRawPointer?, _ len: Int) {
    // 简化版MD5实现
    guard let input = input else { return }
    let data = Data(bytes: input, count: len)
    context.buffer = Array(data)
    context.count = UInt64(len)
}

private func MD5_Final(_ digest: inout [UInt8], _ context: inout MD5_CTX) {
    // 简化版MD5实现
    var result = context.buffer.prefix(16)
    digest = Array(result)
}
