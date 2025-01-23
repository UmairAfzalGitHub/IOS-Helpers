//
//  File.swift
//  IOS Helpers
//
//  Created by Umair Afzal on 23/01/2025.
//

import UIKit

public class CircularProgressView: UIView {

    private let backgroundLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    // MARK: - Public Properties
    public var backgroundArcColor: UIColor = .white {
        didSet { backgroundLayer.strokeColor = backgroundArcColor.cgColor }
    }

    public var progressArcColor: UIColor = .red {
        didSet { progressLayer.strokeColor = progressArcColor.cgColor }
    }

    public var arcLineWidth: CGFloat = 15 {
        didSet {
            backgroundLayer.lineWidth = arcLineWidth
            progressLayer.lineWidth = arcLineWidth
            setNeedsLayout()
        }
    }


    // MARK: - Initializers
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup View
    private func setupView() {
        // Configure the background arc
        backgroundLayer.strokeColor = backgroundArcColor.cgColor
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = arcLineWidth
        backgroundLayer.lineCap = .round
        layer.addSublayer(backgroundLayer)

        // Configure the progress arc
        progressLayer.strokeColor = progressArcColor.cgColor
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = arcLineWidth
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()

        // Define the arc's path
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let radius = min(bounds.width, bounds.height) / 2 - arcLineWidth / 2
        let startAngle = CGFloat(-Double.pi * 5 / 4)
        let endAngle = CGFloat(Double.pi / 4)

        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)

        // Apply the path to layers
        backgroundLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    // MARK: - Public Methods
    public func setProgress(_ progress: CGFloat, animated: Bool) {
        let clampedProgress = max(0, min(progress, 1)) // Ensure the progress is between 0 and 1
        progressLayer.strokeEnd = clampedProgress

        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.presentation()?.strokeEnd ?? 0
            animation.toValue = clampedProgress
            animation.duration = 0.2
            progressLayer.add(animation, forKey: "progressAnim")
        }
    }

    public func resetProgress(animated: Bool) {
        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.presentation()?.strokeEnd ?? progressLayer.strokeEnd
            animation.toValue = 0
            animation.duration = 0.2
            progressLayer.add(animation, forKey: "progressResetAnim")
        }
        progressLayer.strokeEnd = 0
    }
}

