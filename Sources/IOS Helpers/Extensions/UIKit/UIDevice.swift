
import UIKit

public extension UIDevice {
    // Method to check if the device is a smaller device like iPhone SE or iPhone 6S
    func isSmallerDevice() -> Bool {
        let screenHeight = UIScreen.main.bounds.height // iPhone SE (1st gen) has a screen height of 568 points (4-inch display) // iPhone 6/6S/7/8 have a screen height of 667 points (4.7-inch display)
        return screenHeight <= 667 }
}
