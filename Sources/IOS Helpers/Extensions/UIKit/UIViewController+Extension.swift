
import Foundation
import UIKit

public extension UIViewController {
    func addNavigationBarTitleImage(_ image: UIImage) {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .white
        
        let titleView = UIView()
        titleView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: titleView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 50),
            imageView.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        navigationItem.titleView = titleView
    }

    func topMostViewController() -> UIViewController {
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController!.topMostViewController()
        }
        
        if let tab = self as? UITabBarController {
            if let selectedTab = tab.selectedViewController {
                return selectedTab.topMostViewController()
            }
            return tab.topMostViewController()
        }
        
        if self.presentedViewController == nil {
            return self
        }
        
        if let navigation = self.presentedViewController as? UINavigationController {
            return navigation.visibleViewController!.topMostViewController()
        }
        
        if let tab = self.presentedViewController as? UITabBarController {
            
            if let selectedTab = tab.selectedViewController {
                return selectedTab.topMostViewController()
            }
            
            return tab.topMostViewController()
        }
        
        return self.presentedViewController!.topMostViewController()
    }
    
    func dismissOnTap() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissViewControllerOnTap))
        tapGesture.delegate = self
        self.view.addGestureRecognizer(tapGesture)
        self.view.isUserInteractionEnabled = true
    }
    
    @objc func dismissViewControllerOnTap(gesture: UIGestureRecognizer) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func showAlert(title: String,
                   message: String,
                   completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        })
        self.present(alert, animated: true)
    }
    
    // getting top view controller currently visible
    func topViewController() -> UIViewController {
        
        if let presented = self.presentedViewController {
            return presented.topViewController()
        }
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topViewController() ?? navigation
        }
        
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topViewController() ?? tab
        }
        
        return self
    }

    /// To get the topMost visible viewController
    ///
    /// - returns:  An optional top most viewController of the application
    static func topMostController() -> UIViewController? {
        var topController: UIViewController? = UIApplication.shared.sceneWindow?.rootViewController
        while ((topController?.presentedViewController) != nil) {
            topController = topController?.presentedViewController
        }
        return topController
    }
}

extension UIViewController: @retroactive UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == gestureRecognizer.view
    }
}
