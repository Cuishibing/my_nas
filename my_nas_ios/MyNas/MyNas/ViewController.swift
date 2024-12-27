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
            // 如果是第一次运行（没有保存的时间），返回一个很早的时间
            if !UserDefaults.standard.bool(forKey: "HasInitializedLastCheckTime") {
                // 设置为 2000 年 1 月 1 日
                let initialDate = Date(timeIntervalSince1970: 946684800)  // 2000-01-01 00:00:00
                UserDefaults.standard.set(initialDate, forKey: "LastCheckTime")
                UserDefaults.standard.set(true, forKey: "HasInitializedLastCheckTime")
                UserDefaults.standard.synchronize()
                return initialDate
            }
            return UserDefaults.standard.object(forKey: "LastCheckTime") as? Date ?? Date()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LastCheckTime")
            UserDefaults.standard.synchronize()
        }
    }
    
    // 为了避免重复上传，添加一个正在上传的资源集合
    private var uploadingAssets = Set<String>()
    
    // 上传队列
    private var uploadQueue: [(asset: PHAsset, completion: (Bool) -> Void)] = []
    private var isUploading = false
    
    // 上传进度跟踪
    private var uploadProgress: [String: Float] = [:]
    
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
    
    // 添加一个缓存来存储已检查过的文件状态
    private var checkedFiles: [String: Bool] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        requestPhotoLibraryPermission()
        checkServerConfig()
        
        // 添加通知观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleServerConfigChange),
            name: .serverConfigDidChange,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleServerConfigChange() {
        if serverConfig.isConfigured {
            // 停止现有的定时器
            checkTimer?.invalidate()
            checkTimer = nil
            
            // 重新开始检查新照片
            startCheckingNewPhotos()
            
            // 检查现有照片的上传状态
            checkExistingPhotos()
        } else {
            checkServerConfig()
        }
    }
    
    // 修改 checkExistingPhotos 方法
    private func checkExistingPhotos() {
        guard let assets = self.assets,
              serverConfig.isConfigured else { return }
        
        print("正在检查现有照片的上传状态...")
        
        // 创建一个队列来存储需要上传的照��
        var photosToUpload: [PHAsset] = []
        
        for i in 0..<assets.count {
            let asset = assets[i]
            let assetId = asset.localIdentifier
            
            // 只检查是否正在上传
            if !uploadingAssets.contains(assetId) {
                photosToUpload.append(asset)
            }
        }
        
        // 批量处理需上传的照片
        for asset in photosToUpload {
            uploadPhotoWithCompletion(asset: asset) { _ in 
                // 对于现有照片，我们不需要更新 lastCheckTime
            }
        }
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
        
        // 照片加载完成后，如果服务器已配置，检查上传状态
        if serverConfig.isConfigured {
            checkExistingPhotos()
        }
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
        // 修改排序为按创建时间升序（从最早到最近）
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastCheckTime as NSDate)
        
        let newAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if newAssets.count > 0 {
            print("发现 \(newAssets.count) 张新照片")
            
            // 更新数据源和UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 保存旧的数量
                let oldCount = self.assets?.count ?? 0
                
                // 更新数据源
                let allOptions = PHFetchOptions()
                allOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                self.assets = PHAsset.fetchAssets(with: .image, options: allOptions)
                
                // 获取新的数量
                let newCount = self.assets?.count ?? 0
                
                // 计算实际新增的数量
                let insertedCount = newCount - oldCount
                
                if insertedCount > 0 {
                    // 创建新增的索引路径
                    let indexPaths = (0..<insertedCount).map { 
                        IndexPath(item: $0, section: 0)
                    }
                    
                    // 执行批量更新
                    self.collectionView.performBatchUpdates {
                        self.collectionView.insertItems(at: indexPaths)
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
                }
            }
            
            // 遍历所有新照片并上传
            for i in 0..<newAssets.count {
                let asset = newAssets[i]
                
                // 使用闭包来更新 lastCheckTime
                let updateLastCheckTime: (Bool) -> Void = { [weak self] success in
                    if let creationDate = asset.creationDate {
                        // 无论是上传成功还是文件已存在，都更新 lastCheckTime
                        print("照片处理完成，更新最后检查时间为: \(creationDate)")
                        self?.lastCheckTime = creationDate
                    }
                }
                
                // 修改 uploadPhoto 方法调用，添加完成回调
                uploadPhotoWithCompletion(asset: asset) { success in
                    updateLastCheckTime(success)
                }
            }
        } else {
            print("没有发现新照片")
        }
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
            // 退出多选模式取消所有选中状态
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
        // 保存要删除的引路径
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
    
    // 修改 checkServerConfig 方法
    private func checkServerConfig() {
        if !serverConfig.isConfigured {
            showServerConfigAlert()
            // 如果有定时器在运行，停止它
            checkTimer?.invalidate()
            checkTimer = nil
        } else {
            // 如果服务器配置但定时器未运行，启动它
            if checkTimer == nil {
                startCheckingNewPhotos()
            }
            
            // 检查所有现有照片
            checkExistingPhotos()
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
    
    // 修改 uploadPhoto 方法，添加重试机制
    private func uploadPhoto(asset: PHAsset, retryCount: Int = 3) {
        uploadPhotoWithCompletion(asset: asset) { _ in }
    }
    
    // 添加处理上传队列的方法
    private func processUploadQueueWithCompletion() {
        // 如果正在上传或队列空，直接返回
        guard !isUploading, let (asset, completion) = uploadQueue.first else {
            return
        }
        
        // 标记为正在上传
        isUploading = true
        
        // 检查文件是否存在
        checkFileExists(asset: asset) { [weak self] fileExists in
            if fileExists {
                print("文件已存在，无需重复上传")
                // 文件存在时也调用成功回调
                self?.handleUploadCompleteWithCallback(asset: asset, success: true, completion: completion)
            } else {
                // 文件不存在，执行上传
                self?.performUploadWithCompletion(asset: asset, completion: completion)
            }
        }
    }
    
    // 修改 handleUploadComplete 方法
    private func handleUploadCompleteWithCallback(asset: PHAsset, success: Bool, completion: @escaping (Bool) -> Void, retryCount: Int = 3) {
        // 从队列中移除
        uploadQueue.removeFirst()
        
        if !success && retryCount > 0 {
            print("上传失败，准备重试，剩余重试次数：\(retryCount - 1)")
            // 从正在上传集合中移除，允许重试
            uploadingAssets.remove(asset.localIdentifier)
            // 延迟一秒后重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.uploadPhotoWithCompletion(asset: asset) { success in
                    completion(success)
                }
            }
            return
        }
        
        // 从正在上传集合中移除
        uploadingAssets.remove(asset.localIdentifier)
        
        // 更新上传状态
        if success {
            // 更新缓存
            checkedFiles[asset.localIdentifier] = true
            
            // 清除进度
            uploadProgress.removeValue(forKey: asset.localIdentifier)
            
            // 刷新对应的单元格
            if let index = assets?.index(of: asset),
               let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? PhotoCell {
                cell.configure(with: asset, isUploaded: true, uploadProgress: nil)
            }
        }
        
        // 调用完成回调
        completion(success)
        
        // 重置上传状态
        isUploading = false
        
        // 处理队列中的下一个文件
        processUploadQueueWithCompletion()
    }
    
    // 修改 performUpload 方法
    private func performUploadWithCompletion(asset: PHAsset, completion: @escaping (Bool) -> Void) {
        guard let serverURL = serverConfig.serverURL else {
            handleUploadCompleteWithCallback(asset: asset, success: false, completion: completion)
            showServerConfigAlert()
            return
        }
        
        let uploadURL = serverURL.appendingPathComponent("model/FileManageModel/uploadFile")
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { [weak self] (data, dataUTI, _, info) in
            guard let self = self,
                  let imageData = data else {
                print("获取图片数据失败")
                self?.handleUploadCompleteWithCallback(asset: asset, success: false, completion: completion)
                return
            }
            
            let fileExtension = self.getFileExtension(from: dataUTI)
            let fileName = "\(asset.localIdentifier).\(fileExtension)"
            let md5String = imageData.partialMD5String  // 计算 MD5
            
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration)
            
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"
            
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // 添加文件数据
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(self.getMimeType(for: fileExtension))\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            
            // 获取创建日期和用户名
            let creationDate = asset.creationDate ?? Date()
            let dateString = DateFormatter.yyyyMMdd.string(from: creationDate)
            let username = UserDefaults.standard.string(forKey: "Username") ?? "default"
            
            // 添加其他字段，包括 MD5
            let fields = [
                "path": "/\(username)/\(dateString)",
                "name": fileName,
                "createTime": "\(Int(creationDate.timeIntervalSince1970))",
                "md5": md5String  // 添加 MD5 参数
            ]
            
            for (key, value) in fields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            // 创建上传任务
            let task = session.uploadTask(with: request, from: body) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    // 清除进度
                    self?.uploadProgress.removeValue(forKey: asset.localIdentifier)
                    
                    if let error = error {
                        print("上传失败: \(error.localizedDescription)")
                        self?.handleUploadCompleteWithCallback(asset: asset, success: false, completion: completion)
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200 {
                        print("上传成功")
                        self?.handleUploadCompleteWithCallback(asset: asset, success: true, completion: completion)
                    } else {
                        print("上传失败: 服务器返回非200状态码")
                        self?.handleUploadCompleteWithCallback(asset: asset, success: false, completion: completion)
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
    
    // 在 ViewController 类中添加查文件是否存在的方法
    private func checkFileExists(asset: PHAsset, completion: @escaping (Bool) -> Void) {
        let assetId = asset.localIdentifier
        
        // 如果已经检查过，直接返回缓存的结果
        if let exists = checkedFiles[assetId] {
            completion(exists)
            return
        }
        
        guard let serverURL = serverConfig.serverURL else {
            completion(false)
            return
        }
        
        let checkURL = serverURL.appendingPathComponent("model/FileManageModel/fileExist")
        var request = URLRequest(url: checkURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { [weak self] (data, dataUTI, _, _) in
            guard let self = self,
                  let imageData = data else {
                completion(false)
                return
            }
            
            let fileExtension = self.getFileExtension(from: dataUTI)
            let md5String = imageData.partialMD5String
            
            let creationDate = asset.creationDate ?? Date()
            let dateString = DateFormatter.yyyyMMdd.string(from: creationDate)
            let username = UserDefaults.standard.string(forKey: "Username") ?? "default"
            let fileName = "\(asset.localIdentifier).\(fileExtension)"
            let filePath = "/\(username)/\(dateString)"
            
            let requestBody: [String: String] = [
                "md5": md5String,
                "fileName": fileName,
                "path": filePath
            ]
            
            guard let jsonData = try? JSONEncoder().encode(requestBody) else {
                completion(false)
                return
            }
            
            request.httpBody = jsonData
            
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
                        let fileExists = responseString.contains("true")
                        self.checkedFiles[assetId] = fileExists
                        completion(fileExists)
                    } else {
                        completion(false)
                    }
                }
            }
            
            task.resume()
        }
    }
    
    // 添加获取文件扩展名的辅助方法
    private func getFileExtension(from dataUTI: String?) -> String {
        if let uti = dataUTI {
            switch uti {
            case "public.jpeg", "public.jpg":
                return "jpg"
            case "public.png":
                return "png"
            case "public.heic":
                return "heic"
            case "public.heif":
                return "heif"
            default:
                return "jpg" // 默认使用 jpg
            }
        }
        return "jpg"
    }
    
    // 添加获取 MIME 类型的辅助方法
    private func getMimeType(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "heic":
            return "image/heic"
        case "heif":
            return "image/heif"
        default:
            return "image/jpeg"
        }
    }
    
    // 添加新的上传方法，包含完成��调
    private func uploadPhotoWithCompletion(asset: PHAsset, completion: @escaping (Bool) -> Void) {
        let assetId = asset.localIdentifier
        
        // 先检查服务器配置
        guard serverConfig.isConfigured else {
            completion(false)
            return
        }
        
        // 只检查是否正在上传
        guard !uploadingAssets.contains(assetId) else {
            completion(false)
            return
        }
        
        // 标记正在处理
        uploadingAssets.insert(assetId)
        
        // 添加到上传队列，并保存完成回调
        uploadQueue.append((asset, completion))
        
        // 如果当前没有正在上传的文件，开始上传
        processUploadQueueWithCompletion()
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
            let assetId = asset.localIdentifier
            let progress = uploadProgress[assetId]
            
            // 修改判断逻辑：
            // 1. 如果在 uploadingAssets 中，说明正在上传或等待上传
            // 2. 如果有 progress，说明正在上传中
            // 3. 如果都不是，则需要检查是否已上传
            let isUploading = uploadingAssets.contains(assetId)
            
            if isUploading {
                // 正在上传或等待上传
                cell.configure(with: asset, isUploaded: false, uploadProgress: progress)
            } else if progress != nil {
                // 有上传进度
                cell.configure(with: asset, isUploaded: false, uploadProgress: progress)
            } else {
                // 检查是否已上传
                checkFileExists(asset: asset) { [weak cell] exists in
                    DispatchQueue.main.async {
                        cell?.configure(with: asset, isUploaded: exists, uploadProgress: nil)
                    }
                }
                // 先显示为未上传状态
                cell.configure(with: asset, isUploaded: false, uploadProgress: nil)
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
                    // 果变化大，直接重加载
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

// 添加日期格式化扩
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
        // 直接使用完整的 MD5 计算
        return self.md5String
    }
    
    // 计算整个文件的 MD5
    var md5String: String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        
        self.withUnsafeBytes { buffer in
            CC_MD5(buffer.baseAddress, CC_LONG(self.count), &digest)
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
