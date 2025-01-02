

import Foundation
import UIKit

public extension UIImage {
    
    enum JPEGQuality: CGFloat {
        case lowest  = 0
        case low     = 0.25
        case medium  = 0.5
        case high    = 0.75
        case highest = 1
    }
    
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
    
    convenience init?(base64: String) {
        guard !base64.isEmpty else { return nil}
        
        // Safely unwrap the data from the base64 string
        guard let imageData = Data(base64Encoded: base64) else {
            print("Error: Could not decode base64 string.")
            return nil
        }
        
        // Safely initialize the UIImage with the data
        guard let image = UIImage(data: imageData) else {
            print("Error: Could not initialize UIImage with the provided data.")
            return nil
        }
        
        // Initialize the image
        self.init(cgImage: image.cgImage!)
    }
    
    func transform(withNewColor color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.setBlendMode(.normal)
        
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        context.clip(to: rect, mask: cgImage!)
        
        color.setFill()
        context.fill(rect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    /// Returns the data for the specified image in PNG format
    /// If the image object’s underlying image data has been purged, calling this function forces that data to be reloaded into memory.
    /// - returns: A data object containing the PNG data, or nil if there was a problem generating the data. This function may return nil if the image has no data or if the underlying CGImageRef contains data in an unsupported bitmap format.
    var png: Data? { return self.pngData() }
    
    /// Returns the data for the specified image in JPEG format.
    /// If the image object’s underlying image data has been purged, calling this function forces that data to be reloaded into memory.
    /// - returns: A data object containing the JPEG data, or nil if there was a problem generating the data. This function may return nil if the image has no data or if the underlying CGImageRef contains data in an unsupported bitmap format.
    func jpeg(_ quality: JPEGQuality) -> Data? {
        return self.jpegData(compressionQuality: quality.rawValue)
    }
    
    func resize(to newSize: CGSize) -> UIImage? {
        // Create a graphics context with the new size
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        // Draw the original image into the resized context
        self.draw(in: CGRect(origin: .zero, size: newSize))
        
        // Capture the new image from the context
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        // End the graphics context
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
}
