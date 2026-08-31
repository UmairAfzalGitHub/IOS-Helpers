// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IOS Helpers",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        // Foundation/UIKit extensions + shared controls. Dependency-free — safe for
        // any app to consume without pulling in ads/analytics SDKs.
        .library(
            name: "IOS Helpers",
            targets: ["IOS Helpers"]),
        // Firebase Analytics/Crashlytics wrapper. One `AppAnalytics` entry point so
        // every app logs through the same API (and the same pinned Firebase version).
        .library(
            name: "AnalyticsKit",
            targets: ["AnalyticsKit"]),
        // AdMob + UMP consent. `AdManager` (banners/interstitials/native/rewarded/
        // app-open) and `AdsConsentManager` (ATT + GDPR). Per-app ad-unit ids and the
        // subscription check are injected via `AdManager.shared.configure(...)`.
        .library(
            name: "AdsKit",
            targets: ["AdsKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "13.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "IOS Helpers"),
        .target(
            name: "AnalyticsKit",
            dependencies: [
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
            ]),
        .target(
            name: "AdsKit",
            dependencies: [
                "IOS Helpers",
                "AnalyticsKit",
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "GoogleUserMessagingPlatform", package: "swift-package-manager-google-user-messaging-platform"),
            ]),
        .testTarget(
            name: "IOS HelpersTests",
            dependencies: ["IOS Helpers"]),
    ]
)
