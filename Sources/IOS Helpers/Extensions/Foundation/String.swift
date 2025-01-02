
import UIKit
import Foundation

public extension String {
    
    static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    var date: Date? {
        return String.dateFormatter.date(from: self)
    }
    
    var length: Int {
        return self.count
    }
    
    var notEmpty: Bool {
        return !isEmpty
    }
    
    var isEqual: Bool {
        return self == self
    }
    
    func fromBase64() -> String {
        let data = Data(base64Encoded: self, options: NSData.Base64DecodingOptions(rawValue: 0))
        return String(data: data!, encoding: String.Encoding.utf8)!
    }
    
    func toBase64() -> String{
        let data = self.data(using: String.Encoding.utf8)
        return data!.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
    }
    
    func isValidEmail() -> Bool {
        let emailFormat = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailFormat)
        
        let result =  emailPredicate.evaluate(with: self)
        return result
    }
    
    func isValidURL() -> Bool {
        guard let url = URL(string: self) else {
            return false // Not a valid URL
        }
        
        // Check if the URL has a valid scheme (http or https)
        let validSchemes = ["http", "https"]
        return validSchemes.contains(url.scheme?.lowercased() ?? "") && url.host != nil
    }
    
    func isValidFacebookURL() -> Bool {
        guard let url = URL(string: self) else {
            return false // Not a valid URL
        }
        
        // Check if the URL has a valid scheme (http or https) and a Facebook host
        let validSchemes = ["http", "https"]
        let validHosts = ["www.facebook.com", "facebook.com", "m.facebook.com"]
        
        return validSchemes.contains(url.scheme?.lowercased() ?? "") &&
        validHosts.contains(url.host?.lowercased() ?? "")
    }
    
    func isValidInstagramURL() -> Bool {
        guard let url = URL(string: self) else {
            return false // Not a valid URL
        }
        
        // Check if the URL has a valid scheme (http or https) and an Instagram host
        let validSchemes = ["http", "https"]
        let validHosts = ["www.instagram.com", "instagram.com"]
        
        return validSchemes.contains(url.scheme?.lowercased() ?? "") &&
        validHosts.contains(url.host?.lowercased() ?? "")
    }
    
    func isValidTwitterURL() -> Bool {
        let twitterPattern = "^(https?://)?(www\\.)?(x\\.com|twitter\\.com)/[A-Za-z0-9_]+/?$"
        let twitterRegex = NSPredicate(format: "SELF MATCHES %@", twitterPattern)
        return twitterRegex.evaluate(with: self)
    }
    
    func isValidPassword() -> Bool {
        // Regex pattern that meets all the password requirements
        let passwordRegex = "^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[!@#$%^&*(),.?\":{}|<>]).{8,}$"
        
        // Validate using NSPredicate
        let passwordTest = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordTest.evaluate(with: self)
    }
    
    static func makeTextBold(_ preBoldText: String,
                             boldText: String,
                             postBoldText: String,
                             font: UIFont = UIFont(),
                             fontSzie: CGFloat) -> NSAttributedString {
        
        let boldAttrs = [NSAttributedString.Key.font: font.withSize(fontSzie) as AnyObject]
        let attributedString = NSMutableAttributedString(string:boldText, attributes:boldAttrs as [NSAttributedString.Key:AnyObject])
        
        let lightAttr = [NSAttributedString.Key.font: font.withSize(fontSzie) as AnyObject]
        let finalAttributedText = NSMutableAttributedString(string:preBoldText, attributes:lightAttr as [NSAttributedString.Key:AnyObject])
        
        let postText = NSMutableAttributedString(string:postBoldText, attributes:lightAttr as [NSAttributedString.Key:AnyObject])
        
        finalAttributedText.append(attributedString)
        finalAttributedText.append(postText)
        
        return finalAttributedText
    }

    func safelyLimitedTo(length n: Int)->String {
        if (self.count <= n) { return self }
        return String( Array(self).prefix(upTo: n) )
    }
    
    func grouping(every groupSize: Int, with separator: Character) -> String {
        let cleanedUpCopy = replacingOccurrences(of: String(separator), with: "")
        return String(cleanedUpCopy.enumerated().map() {
            $0.offset % groupSize == 0 ? [separator, $0.element] : [$0.element]
        }.joined().dropFirst())
    }
    
    var html2AttributedString: NSAttributedString? {
        return Data(utf8).html2AttributedString
    }
    var html2String: String {
        return html2AttributedString?.string ?? self
    }
    
    func calculateLabelWidth(font: UIFont) -> CGFloat {
        let nsString = NSString(string: self)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = nsString.size(withAttributes: attributes)
        return size.width
    }
    
    var image: UIImage? {
        if let image = UIImage(systemName: self) {
            return image
        } else {
            return UIImage(named: self)
        }
    }
}
