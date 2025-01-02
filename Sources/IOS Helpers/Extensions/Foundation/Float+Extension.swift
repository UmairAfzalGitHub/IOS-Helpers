
import Foundation

public extension Float {
    
    func toHHMM() -> String {
        // Extract the whole hours part (e.g., 12 in 12.75)
        let hoursPart = Int(self)
        // Convert the decimal part of the hours to minutes (e.g., .75 * 60 = 45 minutes)
        let minutesPart = Int((self - Float(hoursPart)) * 60)
        // Format the output as "hours:minutes", ensuring two digits for minutes
        return String(format: "%d:%02d", hoursPart, minutesPart)
    }
}
