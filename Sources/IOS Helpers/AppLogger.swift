//
//  AppLogger.swift
//  IOS Helpers
//
//  Unified logging. Every message is prefixed with `App-Logs:` so it can be
//  filtered easily in the Xcode/device console. Shared so package code (AdsKit,
//  …) and the host app log through the same channel.
//

import Foundation

public enum AppLogger {

    /// Log prefix used for all logs. Filter the console by this string to see
    /// only logs coming from the app / shared helpers.
    public static var prefix = "App-Logs:"

    /// When `false`, `log(_:)` is a no-op. Defaults to `true` in DEBUG and
    /// `false` in release, so shipping builds don't spew to the console. Apps can
    /// override this at launch.
    public static var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Drop-in replacement for `print`. Accepts the same variadic arguments,
    /// joins them with `separator`, and prints them prefixed with `prefix`.
    public static func log(_ items: Any...,
                           separator: String = " ",
                           terminator: String = "\n") {
        guard isEnabled else { return }
        let message = items.map { String(describing: $0) }.joined(separator: separator)
        print("\(prefix) \(message)", terminator: terminator)
    }
}
