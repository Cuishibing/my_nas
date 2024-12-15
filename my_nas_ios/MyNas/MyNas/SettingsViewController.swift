import UIKit

class SettingsViewController: UIViewController {
    
    private let serverAddressTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "请输入服务器地址"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        return textField
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("保存", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedAddress()
    }
    
    private func setupUI() {
        title = "设置"
        view.backgroundColor = .systemBackground
        
        // 设置文本框约束
        view.addSubview(serverAddressTextField)
        serverAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            serverAddressTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            serverAddressTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            serverAddressTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            serverAddressTextField.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 设置保存按钮约束
        view.addSubview(saveButton)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: serverAddressTextField.bottomAnchor, constant: 20),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        serverAddressTextField.delegate = self
    }
    
    private func loadSavedAddress() {
        serverAddressTextField.text = UserDefaults.standard.string(forKey: "ServerAddress")
    }
    
    @objc private func saveButtonTapped() {
        guard let address = serverAddressTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty else {
            showAlert(message: "请输入有效的服务器地址")
            return
        }
        
        UserDefaults.standard.set(address, forKey: "ServerAddress")
        UserDefaults.standard.synchronize()
        
        showAlert(message: "保存成功") { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
    
    private func showAlert(message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

extension SettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
