
import Foundation
import UIKit

public extension UIApplication {
    
    var keyWindow: UIWindow? {
        // Get connected scenes
        return self.connectedScenes
        // Keep only active scenes, onscreen and visible to the user
            .filter { $0.activationState == .foregroundActive }
        // Keep only the first `UIWindowScene`
            .first(where: { $0 is UIWindowScene })
        // Get its associated windows
            .flatMap({ $0 as? UIWindowScene })?.windows
        // Finally, keep only the key window
            .first(where: \.isKeyWindow)
    }
    
    var visibleViewController: UIViewController? {
        
        guard let rootViewController = keyWindow?.rootViewController else {
            return nil
        }
        
        return getVisibleViewController(rootViewController)
    }
    
    func getVisibleViewController(_ rootViewController: UIViewController?) -> UIViewController? {
        
        var rootVC = rootViewController
        
        if rootVC == nil {
            rootVC = keyWindow?.rootViewController
        }
        
        if rootVC?.presentedViewController == nil {
            return rootVC
        }
        
        if let presented = rootVC?.presentedViewController {
            
            if presented.isKind(of: UINavigationController.self) {
                let navigationController = presented as! UINavigationController
                return navigationController.viewControllers.last!
            }
            
            if presented.isKind(of: UITabBarController.self) {
                let tabBarController = presented as! UITabBarController
                return tabBarController.selectedViewController!
            }
            
            return getVisibleViewController(presented)
        }
        return nil
    }
    
    func updateRootViewController(
          to viewController: UIViewController,
          animated: Bool = true
      ) {
          guard let window = connectedScenes
                  .filter({ $0.activationState == .foregroundActive })
                  .compactMap({ $0 as? UIWindowScene })
                  .first?.windows.first(where: { $0.isKeyWindow }) else {
              print("No key window found.")
              return
          }
          
          if animated {
              let snapshot = window.snapshotView(afterScreenUpdates: true)
              viewController.view.addSubview(snapshot ?? UIView())
              window.rootViewController = viewController
              
              UIView.animate(withDuration: 0.3, animations: {
                  snapshot?.alpha = 0
              }, completion: { _ in
                  snapshot?.removeFromSuperview()
              })
          } else {
              window.rootViewController = viewController
          }
      }
    
    var sceneWindow: UIWindow? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        return keyWindow
    }
    
    var topViewController: UIViewController? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        return keyWindow.rootViewController?.topViewController()
    }
}
