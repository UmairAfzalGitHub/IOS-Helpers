
import Foundation
import UIKit

public extension UINavigationController {
    
    func transparentNavigationBar() {
        self.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationBar.shadowImage = UIImage()
        self.navigationBar.isTranslucent = true
        self.navigationBar.barTintColor = UIColor.clear
        self.navigationBar.backgroundColor = .clear
    }
    
    func setupHomeNavigationBar() {
        self.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationBar.shadowImage = UIImage()
        navigationBar.tintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        self.navigationBar.isTranslucent = true
    }
    
    func nonTransparentNavigationBar() {
        self.navigationBar.setBackgroundImage(UIImage(color: #colorLiteral(red: 0.9996390939, green: 1, blue: 0.9997561574, alpha: 1)), for: .default)
        self.navigationBar.shadowImage = UIImage()
        self.navigationBar.isTranslucent = false
        self.navigationBar.barTintColor = .black
        self.navigationBar.backgroundColor = #colorLiteral(red: 0.9996390939, green: 1, blue: 0.9997561574, alpha: 1)
    }
}
