
import Foundation

public extension Double {
    
    func timeStringFromUnixTime(dateFormatter: DateFormatter, deviderValue: Double = 1) -> String {
        let date = Date(timeIntervalSince1970: self/deviderValue)
        return dateFormatter.string(from: date)
    }
    
    func toString() -> String {
        return String(self)
    }
    
    func toHHMM() -> String {
        // Extract the whole hours part (e.g., 7 in 7.98)
        let hoursPart = Int(self)
        // Convert the fractional hours part to minutes, with rounding
        let fractionalPart = self - Double(hoursPart)
        let minutesPart = Int((fractionalPart * 60).rounded())
        // Format the output as "hours:minutes", ensuring two digits for minutes
        return String(format: "%d:%02d", hoursPart, minutesPart)
    }
}
