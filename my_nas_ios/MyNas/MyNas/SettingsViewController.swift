import UIKit

class SettingsViewController: UIViewController {
    
    private let ipAddressLabel: UILabel = {
        let label = UILabel()
        label.text = "服务器IP地址"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let portLabel: UILabel = {
        let label = UILabel()
        label.text = "端口号"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let ipAddressTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "例如：192.168.1.100"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .next
        textField.clearButtonMode = .whileEditing
        textField.keyboardType = .numbersAndPunctuation
        return textField
    }()
    
    private let portTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "例如：8080"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.keyboardType = .numberPad
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
        
        // 设置IP地址标签和输入框约束
        view.addSubview(ipAddressLabel)
        view.addSubview(ipAddressTextField)
        
        ipAddressLabel.translatesAutoresizingMaskIntoConstraints = false
        ipAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            ipAddressLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            ipAddressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            ipAddressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            ipAddressTextField.topAnchor.constraint(equalTo: ipAddressLabel.bottomAnchor, constant: 8),
            ipAddressTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            ipAddressTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            ipAddressTextField.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 设置端口标签和输入框约束
        view.addSubview(portLabel)
        view.addSubview(portTextField)
        
        portLabel.translatesAutoresizingMaskIntoConstraints = false
        portTextField.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            portLabel.topAnchor.constraint(equalTo: ipAddressTextField.bottomAnchor, constant: 16),
            portLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            portLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            portTextField.topAnchor.constraint(equalTo: portLabel.bottomAnchor, constant: 8),
            portTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            portTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            portTextField.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // 保存按钮约束
        view.addSubview(saveButton)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: portTextField.bottomAnchor, constant: 24),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        ipAddressTextField.delegate = self
        portTextField.delegate = self
    }
    
    private func loadSavedAddress() {
        ipAddressTextField.text = UserDefaults.standard.string(forKey: "ServerIP")
        portTextField.text = UserDefaults.standard.string(forKey: "ServerPort")
    }
    
    @objc private func saveButtonTapped() {
        guard let ip = ipAddressTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !ip.isEmpty else {
            showAlert(message: "请输入有效的IP地址")
            return
        }
        
        guard let port = portTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !port.isEmpty,
              let portNumber = Int(port),
              portNumber > 0 && portNumber <= 65535 else {
            showAlert(message: "请输入有效的端口号(1-65535)")
            return
        }
        
        UserDefaults.standard.set(ip, forKey: "ServerIP")
        UserDefaults.standard.set(port, forKey: "ServerPort")
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
        if textField == ipAddressTextField {
            portTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
