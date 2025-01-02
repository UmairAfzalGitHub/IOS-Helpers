
import Foundation
import UIKit

public extension NSMutableAttributedString {
    
    @discardableResult func bold(_ text:String, color: UIColor = .black) -> NSMutableAttributedString {
        let attrs:[NSAttributedString.Key:AnyObject] = [NSAttributedString.Key(rawValue: NSAttributedString.Key.font.rawValue): UIFont.systemFont(ofSize: 15.0), NSAttributedString.Key.foregroundColor: color]
        let boldString = NSMutableAttributedString(string: text, attributes:attrs)
        self.append(boldString)
        return self
    }
    
    @discardableResult func attributedString(withText text:String, color: UIColor = .black, alignment : NSTextAlignment, fontSize : CGFloat , isUnderLine: Bool = false, boldString : String? = nil) -> NSMutableAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        var attrs:[NSAttributedString.Key: Any] = [NSAttributedString.Key.foregroundColor: color, .paragraphStyle: paragraph]
        if isUnderLine
        {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
            attrs[NSAttributedString.Key.font] =  UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let attributedString = NSMutableAttributedString(string: text, attributes:attrs)
        
        if let boldString = boldString
        {
            let range = (text as NSString).range(of: boldString)
            attributedString.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: fontSize), range: range)
        }
        
        self.append(attributedString)
        return self
    }
    
    func attributedString(withText text:String, color: UIColor = .black, alignment : NSTextAlignment, font : UIFont, underlineString: String? = nil, boldString : String? = nil, blodFont : UIFont? = nil) -> NSMutableAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let attrs:[NSAttributedString.Key: Any] = [NSAttributedString.Key.foregroundColor: color, .paragraphStyle: paragraph, .font : font]
        
        let attributedString = NSMutableAttributedString(string: text, attributes:attrs)
        
        if let boldString = boldString
        {
            let range = (text as NSString).range(of: boldString)
            attributedString.addAttribute(NSAttributedString.Key.font, value: blodFont ?? UIFont.systemFont(ofSize: font.pointSize + 4.0), range: range)
        }
        
        if let underlineString = underlineString
        {
            let range = (text as NSString).range(of: underlineString)
            attributedString.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        
        self.append(attributedString)
        return self
    }
    
    @discardableResult func normal(_ text:String)->NSMutableAttributedString {
        let normal = NSAttributedString(string: text, attributes: [NSAttributedString.Key.foregroundColor : UIColor.black])
        self.append(normal)
        return self
    }
}

