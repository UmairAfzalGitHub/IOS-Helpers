
import UIKit

public extension UIDevice {
    
    func isNotchlessDevice() -> Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            // Default to false if we can't determine
            return false
        }
        
        // Check if running on simulator
#if targetEnvironment(simulator)
        // Simulator-specific check
        let deviceName = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? UIDevice.current.modelIdentifier
        
        // List of known notchless simulator identifiers
        let notchlessSimulatorModels = [
            "iPhone1,1", "iPhone1,2",    // iPhone, iPhone 3G
            "iPhone2,1",                // iPhone 3GS
            "iPhone3,1", "iPhone3,2", "iPhone3,3", // iPhone 4, 4S
            "iPhone4,1",                // iPhone 4S
            "iPhone5,1", "iPhone5,2",   // iPhone 5
            "iPhone5,3", "iPhone5,4",   // iPhone 5C
            "iPhone6,1", "iPhone6,2",   // iPhone 5S
            "iPhone7,2",                // iPhone 6
            "iPhone7,1",                // iPhone 6 Plus
            "iPhone8,1",                // iPhone 6S
            "iPhone8,2",               // iPhone 6S Plus
            "iPhone8,4",               // iPhone SE (1st gen)
            "iPhone9,1", "iPhone9,3",  // iPhone 7
            "iPhone9,2", "iPhone9,4",  // iPhone 7 Plus
            "iPhone10,1", "iPhone10,4", // iPhone 8
            "iPhone10,2", "iPhone10,5", // iPhone 8 Plus
            "iPhone12,8",              // iPhone SE (2nd gen)
            "iPhone14,6"               // iPhone SE (3rd gen)
        ]
        
        return notchlessSimulatorModels.contains(deviceName)
#else
        // Physical device check
        let hasNotch = window.safeAreaInsets.top > 20 // Status bar height is typically 20pt on notchless
        
        let deviceModel = UIDevice.current.modelIdentifier
        
        // List of known notchless iPhone models
        let notchlessModels = [
            "iPhone1,1", "iPhone1,2",    // iPhone, iPhone 3G
            "iPhone2,1",                // iPhone 3GS
            "iPhone3,1", "iPhone3,2", "iPhone3,3", // iPhone 4, 4S
            "iPhone4,1",                // iPhone 4S
            "iPhone5,1", "iPhone5,2",   // iPhone 5
            "iPhone5,3", "iPhone5,4",   // iPhone 5C
            "iPhone6,1", "iPhone6,2",   // iPhone 5S
            "iPhone7,2",                // iPhone 6
            "iPhone7,1",                // iPhone 6 Plus
            "iPhone8,1",                // iPhone 6S
            "iPhone8,2",               // iPhone 6S Plus
            "iPhone8,4",               // iPhone SE (1st gen)
            "iPhone9,1", "iPhone9,3",  // iPhone 7
            "iPhone9,2", "iPhone9,4",  // iPhone 7 Plus
            "iPhone10,1", "iPhone10,4", // iPhone 8
            "iPhone10,2", "iPhone10,5", // iPhone 8 Plus
            "iPhone12,8",              // iPhone SE (2nd gen)
            "iPhone14,6"               // iPhone SE (3rd gen)
        ]
        
        return !hasNotch || notchlessModels.contains(deviceModel)
#endif
    }
    
    // Extension to get device identifier
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    // Method to check if the device is a smaller device like iPhone SE or iPhone 6S
    func isSmallerDevice() -> Bool {
        let screenHeight = UIScreen.main.bounds.height // iPhone SE (1st gen) has a screen height of 568 points (4-inch display) // iPhone 6/6S/7/8 have a screen height of 667 points (4.7-inch display)
        return screenHeight <= 667
    }
}
