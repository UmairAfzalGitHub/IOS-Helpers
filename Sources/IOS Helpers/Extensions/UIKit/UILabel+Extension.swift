
import UIKit

public extension UILabel {
    func setLineHeight(_ lineHeight: CGFloat) {
        guard let text = self.text else { return }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineHeight - self.font.lineHeight
        paragraphStyle.alignment = self.textAlignment
        
        let attributedString: NSMutableAttributedString
        if let currentAttributedText = self.attributedText {
            attributedString = NSMutableAttributedString(attributedString: currentAttributedText)
        } else {
            attributedString = NSMutableAttributedString(string: text)
        }
        
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
        attributedString.addAttribute(.font, value: self.font as Any, range: NSRange(location: 0, length: attributedString.length))
        
        self.attributedText = attributedString
    }
    
    func setScreenHeadingLabel(text: String) {
        self.text = text
        font = UIFont.appThemeSemiBoldFontWithSize(32)
        textColor = Colors.BlueZodiac
        setLineHeight(48)
    }
    
    func setScreenSubHeadingLabel(text: String) {
        self.numberOfLines = 0
        self.text = text
        font = UIFont.appThemeFontWithSize(16)
        textColor = Colors.BrightGrey
        setLineHeight(24)
    }
}
