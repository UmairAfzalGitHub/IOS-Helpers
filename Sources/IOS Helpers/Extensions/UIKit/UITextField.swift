
import Foundation
import UIKit

private var __maxLengths = [UITextField: Int]()

public extension UITextField {
    
    @IBInspectable var maxLength: Int {
        get {
            guard let l = __maxLengths[self] else {
                return 150 // (global default-limit. or just, Int.max)
            }
            return l
        }
        set {
            __maxLengths[self] = newValue
            addTarget(self, action: #selector(fix), for: .editingChanged)
        }
    }
    
    @objc func fix(textField: UITextField) {
        let t = textField.text
        textField.text = t?.safelyLimitedTo(length: maxLength)
    }
    
    func useUnderline(with color:UIColor) {
        
        let border = CALayer()
        let borderWidth = CGFloat(1.0)
        border.borderColor = color.cgColor
        border.frame = CGRect(x: 0, y: self.frame.size.height - borderWidth, width: self.frame.size.width, height: self.frame.size.height)
        border.borderWidth = borderWidth
        self.layer.addSublayer(border)
        self.layer.masksToBounds = true
    }
    
    func setImageToRightView(image: UIImage?,
                             selectedImage: UIImage?,
                             width: CGFloat = 20.0,
                             height: CGFloat = 20.0,
                             action: Selector?, target: Any) {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(image, for: .normal)
        button.setImage(selectedImage, for: .selected)
        button.isSelected = false
        button.imageView?.contentMode = .scaleAspectFit
        button.clipsToBounds = true
        button.isUserInteractionEnabled = true
        
        if let imageView = button.imageView {
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: width * 0.8),
                imageView.heightAnchor.constraint(equalToConstant: height * 0.8),
                button.widthAnchor.constraint(equalToConstant: width),
                button.heightAnchor.constraint(equalToConstant: height)
            ])
        }
        
        //        button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 10)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        
        if let action = action {
            button.addTarget(target, action: action, for: .touchUpInside)
        }
        
        self.rightView = button
        self.rightViewMode = .always
    }
    
    func setImageToLeftView(image: UIImage?,
                            selectedImage: UIImage,
                            title: String?,
                            width: CGFloat = 20.0,
                            height: CGFloat = 20.0,
                            action: Selector?,
                            target: Any,
                            imageEdgeInsets: UIEdgeInsets) {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(image, for: .normal)
        button.setImage(selectedImage, for: .selected)
        button.isSelected = true
        button.imageView?.contentMode = .scaleAspectFit
        button.clipsToBounds = true
        button.tag = 1111
        
        // Set title and adjust font size
        if let title {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14.0)
            button.titleLabel?.textColor = .black
            button.setTitleColor(.black, for: .normal)
            button.setTitleColor(.black, for: .selected)
        }
        // Adjust button title and image layout
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        button.imageEdgeInsets = imageEdgeInsets
        
        // Set button frame
        button.frame = CGRect(x: 100, y: 0, width: title == nil ? width : width + 30, height: height) // Adjust width to accommodate title
        
        // Add action if provided
        if let action = action {
            button.addTarget(target, action: action, for: .touchUpInside)
        }
        
        // Set left view
        self.leftView = button
        self.leftViewMode = .always
    }
    
}
