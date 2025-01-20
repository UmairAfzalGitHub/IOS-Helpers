//
//  File.swift
//  
//
//  Created by Umair Afzal on 20/01/2025.
//

import UIKit

public protocol CountdownLabelDelegate: AnyObject {
    func countdownDidFinish()
}

public class CountdownLabel: UILabel {
    
    // MARK: - Properties
    private var timer: Timer?
    private var remainingTime: TimeInterval = 0
    private var isPaused: Bool = false
    private var delegate: CountdownLabelDelegate?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLabel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLabel()
    }
    
    private func setupLabel() {
        updateLabelText()
    }
    
    // MARK: - Public Methods
    
    /// Starts the countdown from the specified time (in seconds).
    public func startCountdown(from time: TimeInterval, delegate: CountdownLabelDelegate? = nil) {
        self.delegate = delegate
        remainingTime = time
        isPaused = false
        startTimer()
    }
    
    /// Pauses the countdown.
    public func pauseCountdown() {
        isPaused = true
        timer?.invalidate()
    }
    
    /// Resumes the countdown if it was paused.
    public func resumeCountdown() {
        guard isPaused else { return }
        isPaused = false
        startTimer()
    }
    
    /// Stops the countdown and resets the time.
    public func stopCountdown() {
        timer?.invalidate()
        timer = nil
        remainingTime = 0
        updateLabelText()
    }
    
    /// Adds more time (in seconds) to the countdown.
    public func addTime(_ time: TimeInterval) {
        remainingTime += time
        updateLabelText()
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        timer?.invalidate() // Invalidate any existing timer
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateCountdown), userInfo: nil, repeats: true)
    }
    
    @objc private func updateCountdown() {
        guard remainingTime > 0 else {
            timer?.invalidate()
            timer = nil
            updateLabelText()
            notifyCountdownFinished()
            return
        }
        
        remainingTime -= 1
        updateLabelText()
    }
    
    private func updateLabelText() {
        let hours = Int(remainingTime) / 3600
        let minutes = (Int(remainingTime) % 3600) / 60
        let seconds = Int(remainingTime) % 60
        self.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func notifyCountdownFinished() {
        delegate?.countdownDidFinish()
    }
}

