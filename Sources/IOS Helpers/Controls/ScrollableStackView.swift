//
//  File.swift
//  
//
//  Created by Umair Afzal on 13/01/2025.
//

import UIKit
/// A custom `UIStackView` with scrolling capabilities. Needs a width/height constraint along the `axis` to enable scrolling.
/// Just set `width` or `height` anchor(s) for `horizontal` and `vertical` `axis` respectively.
/// Behaves just like a regular `UIStackView` if no such constraint is provided along the `axis`.
public class ScrollableStackView: UIScrollView {
    // MARK: - Properties
    private let stackView = UIStackView()
    private lazy var stackWidthConstraint: NSLayoutConstraint = {
        let constraint = stackView.widthAnchor.constraint(equalTo: widthAnchor, constant: -1)
        constraint.priority = UILayoutPriority.defaultHigh
        return constraint
    }()
    private lazy var stackHeightConstraint: NSLayoutConstraint = {
        let constraint = stackView.heightAnchor.constraint(equalTo: heightAnchor, constant: -1)
        constraint.priority = UILayoutPriority.defaultHigh
        return constraint
    }()
    private lazy var stackTrailingConstraint: NSLayoutConstraint = {
        let constraint = stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1)
        constraint.priority = UILayoutPriority.defaultHigh
        return constraint
    }()
    private lazy var stackBottomConstraint: NSLayoutConstraint = {
        let constraint = stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1)
        constraint.priority = UILayoutPriority.defaultHigh
        return constraint
    }()
    // MARK: - Lifecycle
    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    override public func awakeFromNib() {
        super.awakeFromNib()
        configure()
    }
    // MARK: - Public
    override public var directionalLayoutMargins: NSDirectionalEdgeInsets {
        get { stackView.directionalLayoutMargins }
        set { stackView.directionalLayoutMargins = newValue }
    }
    /// Determines whether scrolling is enabled based on the `intrinsicContentSize` along the `axis`, useful for handling inequality constraints. Default value is `true`
    public var disableIntrinsicContentSizeScrolling = true {
        didSet {
            updateStackViewConstraints()
        }
    }
    // MARK: - Stack View properties and methods (feel free to add more UIStackView methods :)
    public var axis: NSLayoutConstraint.Axis {
        get { stackView.axis }
        set {
            stackView.axis = newValue
            updateStackViewConstraints()
        }
    }
    public var alignment: UIStackView.Alignment {
        get { stackView.alignment }
        set { stackView.alignment = newValue }
    }
    public var distribution: UIStackView.Distribution {
        get { stackView.distribution }
        set { stackView.distribution = newValue }
    }
    public var spacing: CGFloat {
        get { stackView.spacing }
        set { stackView.spacing = newValue }
    }
    public var isLayoutMarginsRelativeArrangement: Bool {
        get { stackView.isLayoutMarginsRelativeArrangement }
        set { stackView.isLayoutMarginsRelativeArrangement = newValue }
    }
    public var arrangedSubviews: [UIView] {
        stackView.arrangedSubviews
    }
    public func addArrangedSubview(_ view: UIView) {
        stackView.addArrangedSubview(view)
    }
    public func removeArrangedSubview(_ view: UIView) {
        stackView.removeArrangedSubview(view)
    }
    public func addArrangedSubviews(_ views: [UIView]) {
        views.forEach { stackView.addArrangedSubview($0) }
    }
    public func removeArrangedSubviews(_ views: [UIView]) {
        views.forEach { stackView.removeArrangedSubview($0) }
    }
    public func addArrangedSubviews(_ views: UIView...) {
        views.forEach { stackView.addArrangedSubview($0) }
    }
    public func removeArrangedSubviews(_ views: UIView...) {
        views.forEach { stackView.removeArrangedSubview($0) }
    }
    public func insertArrangedSubview(_ view: UIView, at stackIndex: Int) {
        stackView.insertArrangedSubview(view, at: stackIndex)
    }
    public func removeArrangedSubview(at stackIndex: Int) {
        stackView.removeArrangedSubview(stackView.arrangedSubviews[stackIndex])
    }
    public func removeAllArrangedSubviews() {
        stackView.arrangedSubviews.forEach { stackView.removeArrangedSubview($0) }
    }
    public func setCustomSpacing(_ spacing: CGFloat, after view: UIView) {
        stackView.setCustomSpacing(spacing, after: view)
    }
    // MARK: - Private
    private func configure() {
        setupUi()
        updateStackViewConstraints()
    }
    private func setupUi() {
        translatesAutoresizingMaskIntoConstraints = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor)
        ])
    }
    private func updateStackViewConstraints() {
        NSLayoutConstraint.deactivate([
            stackWidthConstraint,
            stackHeightConstraint,
            stackTrailingConstraint,
            stackBottomConstraint
        ])
        if disableIntrinsicContentSizeScrolling {
            if axis == .horizontal {
                // For horizontal axis, activate the height constraint and set up the width constraint
                stackHeightConstraint.isActive = true
                stackWidthConstraint.constant = -1
                stackWidthConstraint.isActive = true
            } else {
                // For vertical axis, activate the width constraint and set up the height constraint
                stackWidthConstraint.isActive = true
                stackHeightConstraint.constant = -1
                stackHeightConstraint.isActive = true
            }
        } else {
            if axis == .horizontal {
                stackHeightConstraint.isActive = true
                stackTrailingConstraint.isActive = true
            } else {
                stackWidthConstraint.isActive = true
                stackBottomConstraint.isActive = true
            }
        }
    }
}

public protocol ScrollableStackViewMarqueeAnimatorDelegate: AnyObject {
    func marqueeAnimator(_ animator: ScrollableStackViewMarqueeAnimator, willMoveView view: UIView)
    func marqueeAnimator(_ animator: ScrollableStackViewMarqueeAnimator, didMoveView view: UIView)
    func marqueeAnimatorDidFinishRevolving(_ animator: ScrollableStackViewMarqueeAnimator)
}

public class ScrollableStackViewMarqueeAnimator {
    // MARK: - Private Properties
    private weak var scrollableStackView: ScrollableStackView?
    private var isAnimating = false
    private var displayLink: CADisplayLink?
    private var scrolledSubviewsCount: Int = 0
    // MARK: - Public properties
    public weak var delegate: ScrollableStackViewMarqueeAnimatorDelegate?
    /// Adjust for speed, points per frame. Higher value means faster animation. Default value is `1.0`
    public var animationSpeed: CGFloat
    /// Should keep animating after an iteration. Default value is `true`
    public var shouldAnimateInifitely: Bool
    // MARK: - Lifecycle
    public init(
        scrollView: ScrollableStackView,
        animationSpeed: CGFloat = 1.0,
        shouldAnimateInifitely: Bool = true,
        delegate: ScrollableStackViewMarqueeAnimatorDelegate? = nil
    ) {
        scrollableStackView = scrollView
        self.delegate = delegate
        self.animationSpeed = animationSpeed
        self.shouldAnimateInifitely = shouldAnimateInifitely
    }
    // MARK: - Public
    public func start() {
        guard !isAnimating else { return }
        isAnimating = true
        setupAnimationDisplayLink()
    }
    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isAnimating = false
    }
    public func reset(_ shouldStop: Bool = true) {
        scrollableStackView?.contentOffset = .zero
        if shouldStop {
            stop()
        }
    }
    // MARK: - Private
    private func setupAnimationDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(animateScrollView))
        displayLink?.add(to: .main, forMode: .common)
    }
    @objc
    private func animateScrollView() {
        guard let scrollableStackView else { return }
        // Adjust the contentOffset smoothly
        switch scrollableStackView.axis {
        case .horizontal:
            scrollableStackView.contentOffset.x += animationSpeed
            if let firstView = scrollableStackView.arrangedSubviews.first,
               firstView.frame.maxX < scrollableStackView.contentOffset.x {
                moveToLast(subview: firstView, in: scrollableStackView)
            }
        case .vertical:
            scrollableStackView.contentOffset.y += animationSpeed
            if let firstView = scrollableStackView.arrangedSubviews.first,
               firstView.frame.maxY < scrollableStackView.contentOffset.y {
                moveToLast(subview: firstView, in: scrollableStackView)
            }
        @unknown default:
            fatalError("Unsupported Axis!")
        }
    }
    private func moveToLast(subview view: UIView, in stackView: ScrollableStackView) {
        defer {
            scrolledSubviewsCount += 1
            if scrolledSubviewsCount == stackView.arrangedSubviews.count {
                scrolledSubviewsCount = 0
                delegate?.marqueeAnimatorDidFinishRevolving(self)
            }
        }
        guard shouldAnimateInifitely else { return }
        delegate?.marqueeAnimator(self, willMoveView: view)
        // Append the subview at the end of the stack view
        stackView.addArrangedSubview(view)
        // Adjust contentOffset to create a seamless looping effect
        if stackView.axis == .horizontal {
            let adjustment = view.frame.width + stackView.spacing
            stackView.contentOffset.x -= adjustment
        } else {
            let adjustment = view.frame.height + stackView.spacing
            stackView.contentOffset.y -= adjustment
        }
        delegate?.marqueeAnimator(self, didMoveView: view)
    }
}
