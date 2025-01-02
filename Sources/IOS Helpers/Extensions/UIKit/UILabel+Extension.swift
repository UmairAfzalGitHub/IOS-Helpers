
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
}
