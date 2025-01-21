
import UIKit

@IBDesignable
open class PlaceholderTextView: UITextView {

    public let placeholderLabel: UILabel = UILabel()

    private var placeholderLabelConstraints = [NSLayoutConstraint]()

    @IBInspectable open var placeholder: String = "" {
        didSet {
            placeholderLabel.text = placeholder
        }
    }

    @IBInspectable open var placeholderColor: UIColor = .fontLight {
        didSet {
            placeholderLabel.textColor = placeholderColor
        }
    }

    override open var font: UIFont! {
        didSet {
            if placeholderFont == nil {
                placeholderLabel.font = font
            }
        }
    }

    open var placeholderFont: UIFont? {
        didSet {
            let font = (placeholderFont != nil) ? placeholderFont : self.font
            placeholderLabel.font = font
        }
    }

    override open var textAlignment: NSTextAlignment {
        didSet {
            placeholderLabel.textAlignment = textAlignment
        }
    }

    override open var text: String! {
        didSet {
            textDidChange()
        }
    }

    override open var attributedText: NSAttributedString! {
        didSet {
            textDidChange()
        }
    }

    override open var textContainerInset: UIEdgeInsets {
        didSet {
            updateConstraintsForPlaceholderLabel()
        }
    }

    override public init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textDidChange),
                                               name: UITextView.textDidChangeNotification,
                                               object: nil)

        placeholderLabel.font = UIFont(name: AppConstants.FontName.notoSansHebrew_Medium, size: 16)
        placeholderLabel.textColor = placeholderColor
        placeholderLabel.textAlignment = .center
        placeholderLabel.text = placeholder
        placeholderLabel.numberOfLines = 0
        placeholderLabel.backgroundColor = UIColor.clear
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        self.textColor = .fontLight
        addSubview(placeholderLabel)
        updateConstraintsForPlaceholderLabel()
        
        self.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 0, right: 0)
    }

    private func updateConstraintsForPlaceholderLabel() {
        // Remove any existing constraints for the placeholder
        removeConstraints(placeholderLabelConstraints)
        
        // Create horizontal constraint
        let leadingConstraint = NSLayoutConstraint(
            item: placeholderLabel,
            attribute: .centerX,
            relatedBy: .equal,
            toItem: self,
            attribute: .centerX,
            multiplier: 1.0,
            constant: 0
        )
        
        // Create vertical constraint
        let verticalConstraint = NSLayoutConstraint(
            item: placeholderLabel,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: self,
            attribute: .centerY,
            multiplier: 1.0,
            constant: 0
        )
        // Activate the new constraints
        let newConstraints = [leadingConstraint, verticalConstraint]
        addConstraints(newConstraints)
        
        // Store the constraints for future reference/removal
        placeholderLabelConstraints = newConstraints
    }

    @objc private func textDidChange() {
        placeholderLabel.isHidden = !text.isEmpty
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        placeholderLabel.preferredMaxLayoutWidth = textContainer.size.width - textContainer.lineFragmentPadding * 2.0
    }

    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: UITextView.textDidChangeNotification,
                                                  object: nil)
    }
}
