//
//  AdConfiguration.swift
//  AdsKit
//
//  Per-app ad identity, injected into the shared `AdManager` at launch. The
//  package owns the ad *logic*; each app owns its ad-unit ids (and decides
//  test-vs-live via its own `#if DEBUG`) and supplies them here.
//

import Foundation

// MARK: - Analytics slot names

/// Human-readable slot names used to tag ad analytics events (`"ad_" + rawValue`).
public enum AdTypes: String {
    case appOpenAd = "appOpen_ad"
    case interstitialAd = "interstitial_ad"
    case splashInterstitialAd = "splash_interstitial_ad"
    case paywallInterstitialAd = "paywall_interstitial_ad"
    case nativeAd = "native_ad"
    case bannerAd = "banner_ad"
    case splashBannerAd = "splash_banner_ad"
    case rewardedAd = "rewarded_ad"
}

/// A single ad unit: its AdMob unit id plus the analytics slot it maps to.
public struct AdMobId {
    public var analyticsId: AdTypes
    public var adId: String

    public init(analyticsId: AdTypes, adId: String) {
        self.analyticsId = analyticsId
        self.adId = adId
    }
}

// MARK: - Injected configuration

/// The full set of ad units an app uses. Build one at launch (with the app's own
/// test/live ids) and hand it to `AdManager.shared.configure(_:isSubscribed:)`.
public struct AdConfiguration {
    public var appOpen: AdMobId
    public var interstitial: AdMobId
    public var splashInterstitial: AdMobId
    public var paywallInterstitial: AdMobId
    public var native: AdMobId
    public var languageNative1: AdMobId
    public var languageNative2: AdMobId
    public var countryNative: AdMobId
    public var homeNative: AdMobId
    public var onboardingFullScreenNative: AdMobId
    public var banner: AdMobId
    public var splashBanner: AdMobId
    public var rewarded: AdMobId

    public init(appOpen: AdMobId,
                interstitial: AdMobId,
                splashInterstitial: AdMobId,
                paywallInterstitial: AdMobId,
                native: AdMobId,
                languageNative1: AdMobId,
                languageNative2: AdMobId,
                countryNative: AdMobId,
                homeNative: AdMobId,
                onboardingFullScreenNative: AdMobId,
                banner: AdMobId,
                splashBanner: AdMobId,
                rewarded: AdMobId) {
        self.appOpen = appOpen
        self.interstitial = interstitial
        self.splashInterstitial = splashInterstitial
        self.paywallInterstitial = paywallInterstitial
        self.native = native
        self.languageNative1 = languageNative1
        self.languageNative2 = languageNative2
        self.countryNative = countryNative
        self.homeNative = homeNative
        self.onboardingFullScreenNative = onboardingFullScreenNative
        self.banner = banner
        self.splashBanner = splashBanner
        self.rewarded = rewarded
    }
}
