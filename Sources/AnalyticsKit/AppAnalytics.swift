//
//  AppAnalytics.swift
//  AnalyticsKit
//
//  Thin wrapper over Firebase Analytics + Crashlytics so every app (and shared
//  package code such as AdsKit) logs through one entry point and one pinned
//  Firebase version.
//
//  The host app is still responsible for calling `FirebaseApp.configure()` at
//  launch and for shipping its own `GoogleService-Info.plist`. This type only
//  forwards events once Firebase is configured.
//

import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

public enum AppAnalytics {

    // MARK: - Events

    /// Log a Firebase Analytics event. Parameters are optional — most funnel
    /// events in these apps are name-only.
    public static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }

    /// Set a user property that scopes subsequent events (e.g. `"premium"`).
    public static func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    // MARK: - Crashlytics

    /// Record a non-fatal error to Crashlytics.
    public static func record(_ error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }

    /// Leave a breadcrumb in the current Crashlytics session.
    public static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    /// Attach a key/value pair to the current Crashlytics session.
    public static func setCustomValue(_ value: Any, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
}
