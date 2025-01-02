

import UIKit

public extension UIImageView {
    
    func setupActivityIndicator(color: UIColor = .red) {
        // Check if the activity indicator already exists
        if self.viewWithTag(6565) != nil { return }
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = color
        activityIndicator.tag = 6565
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        
        // Add activity indicator to the UIImageView
        self.addSubview(activityIndicator)
        
        // Center the activity indicator in the UIImageView
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }
    
    func stopActivityIndicator() {
        
        if let activityInficator = self.viewWithTag(6565) {
            activityInficator.removeFromSuperview()
        }
    }
}
