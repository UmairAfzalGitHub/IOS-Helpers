//
//  AdManager.swift
//  AdsKit (v2)
//
//  Generic AdMob manager. The app defines its placements as `AdSlot`s (any number
//  of each format); this manager loads, caches, and presents them keyed by
//  `slot.key`. No fixed slot names, no central AdConfiguration.
//
//  App-specific identity is still injected:
//    • ad-unit ids ride on each `AdSlot`
//    • the "is the user subscribed?" check is an injected closure
//    • analytics go through `AppAnalytics` (AnalyticsKit → Firebase)
//
//  Usage:
//    AdManager.shared.configure(isSubscribed: { IAPManager.shared.isUserSubscribed })
//    AdManager.shared.setupAds()
//    AdManager.shared.preloadInterstitial(Ads.exitInterstitial)
//    AdManager.shared.showInterstitial(Ads.exitInterstitial, from: self)
//    AdManager.shared.loadBanner(Ads.homeBanner, in: self, into: bannerView)
//    AdManager.shared.preloadNative(Ads.resultNative, count: 3)
//    let ad = AdManager.shared.getNative(Ads.resultNative)
//    AdManager.shared.showRewarded(Ads.unlockRewarded, from: self) { earned in … }
//

import Foundation
import GoogleMobileAds
import UIKit
import StoreKit
import IOS_Helpers
import AnalyticsKit
import AppTrackingTransparency
import CryptoKit

public final class AdManager: NSObject, AdLoaderDelegate, NativeAdLoaderDelegate {
    public static let shared = AdManager()
    private override init() { super.init() }

    // MARK: - Injected dependencies

    private var isSubscribedProvider: () -> Bool = { false }

    /// Current subscription state (ads suppressed when true).
    public var isUserSubscribedNow: Bool { isSubscribedProvider() }

    /// Wire the subscription check into the manager. Call once at launch.
    public func configure(isSubscribed: @escaping () -> Bool = { false }) {
        self.isSubscribedProvider = isSubscribed
    }

    // MARK: - Global state

    /// True while any full-screen ad (interstitial / rewarded / app-open) is on
    /// screen — used to prevent overlapping presentations.
    public private(set) var isShowingAd = false

    /// Minimum time between two frequency-gated interstitials. A `showInterstitial`
    /// call with `respectFrequency: true` (default) won't present until this elapses
    /// since the last gated interstitial dismissed. Pass `respectFrequency: false`
    /// for one-shots (splash / first-launch) that must always show.
    public var interstitialMinInterval: TimeInterval = 30
    private var lastInterstitialShownAt: Date?

    // MARK: - SDK init

    private var hasInitializedAds = false
    private var splashSdkInitStartTime: CFTimeInterval = 0
    public private(set) var isSdkReady = false
    private var sdkReadyCallbacks: [() -> Void] = []

    /// Run `block` once the AdMob SDK is initialized (immediately if already ready).
    public func whenSdkReady(_ block: @escaping () -> Void) {
        if isSdkReady { DispatchQueue.main.async { block() } }
        else { sdkReadyCallbacks.append(block) }
    }

    /// Start the AdMob SDK. Idempotent.
    public func setupAds() {
        guard !hasInitializedAds else { return }
        hasInitializedAds = true
        AppLogger.log("📱 Setting up AdMob...")

        #if DEBUG
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? "nil"
        let idfvHash = Self.md5Hex(idfv.uppercased())
        AppLogger.log("📱 IDFV: \(idfv)")
        AppLogger.log("📱 IDFV MD5 (AdMob test device hash): \(idfvHash)")
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["GADSimulatorID", idfvHash]
        #endif

        splashSdkInitStartTime = CACurrentMediaTime()
        AppLogger.log("[SplashAdTiming] SDK_INIT_START — calling MobileAds.shared.start")
        MobileAds.shared.start { [weak self] status in
            guard let self = self else { return }
            let elapsed = CACurrentMediaTime() - self.splashSdkInitStartTime
            AppLogger.log(String(format: "[SplashAdTiming] SDK_INIT_DONE — completion after %.2fs", elapsed))
            AppLogger.log("📱 AdMob SDK initialization completed with status: \(status)")
            let adapterSummary = status.adapterStatusesByClassName
                .map { "\($0.key.components(separatedBy: ".").last ?? $0.key)=\($0.value.state == .ready ? "READY" : "NOT_READY")" }
                .sorted()
                .joined(separator: ", ")
            AppLogger.log("📱 Mediation adapters: [\(adapterSummary)]")

            self.isSdkReady = true
            let callbacks = self.sdkReadyCallbacks
            self.sdkReadyCallbacks.removeAll()
            for cb in callbacks { cb() }
        }
    }

    /// Builds an ad request, attaching npa=1 when ATT is not authorized.
    public static func makeAdRequest(placement: String = "unknown") -> Request {
        let request = Request()
        if ATTrackingManager.trackingAuthorizationStatus != .authorized {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
            AppLogger.log("📶 makeAdRequest[\(placement)] → npa=1 (ATT not authorized)")
        } else {
            AppLogger.log("📶 makeAdRequest[\(placement)] → personalized (ATT authorized)")
        }
        return request
    }

    #if DEBUG
    private static func md5Hex(_ input: String) -> String {
        Insecure.MD5.hash(data: Data(input.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }
    #endif

    // MARK: - StoreKit helpers (optional convenience)

    /// StoreKit 2 entitlement check — true if any auto-renewable subscription is active.
    public func isUserSubscribed() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productType == .autoRenewable { return true }
        }
        return false
    }

    // MARK: - Keyed caches

    private var interstitials: [String: InterstitialAd] = [:]
    private var loadingInterstitials: Set<String> = []

    private var rewardeds: [String: RewardedAd] = [:]
    private var loadingRewardeds: Set<String> = []

    private var appOpens: [String: AppOpenAd] = [:]
    private var loadingAppOpens: Set<String> = []

    private var nativePools: [String: [NativeAd]] = [:]
    private var nativeInFlight: [String: Int] = [:]
    private var nativeLoaders: [AdLoader: (key: String, completion: ((NativeAd?) -> Void)?)] = [:]

    // Full-screen presentation routing, keyed by the presented ad object.
    private var dismissCompletions: [ObjectIdentifier: () -> Void] = [:]
    private var rewardCompletions: [ObjectIdentifier: (Bool) -> Void] = [:]
    private var rewardEarned: Set<ObjectIdentifier> = []

    // MARK: - Format guard

    @discardableResult
    private func expect(_ slot: AdSlot, _ format: AdFormat, _ fn: String = #function) -> Bool {
        guard slot.format == format else {
            AppLogger.log("❌ AdSlot '\(slot.key)' is .\(slot.format) but \(fn) expects .\(format)")
            return false
        }
        return true
    }

    // MARK: - Interstitial

    public func isInterstitialReady(_ slot: AdSlot) -> Bool { interstitials[slot.key] != nil }

    public func preloadInterstitial(_ slot: AdSlot, completion: ((Bool) -> Void)? = nil) {
        guard expect(slot, .interstitial), !isSubscribedProvider() else { completion?(false); return }
        if interstitials[slot.key] != nil { completion?(true); return }
        guard !loadingInterstitials.contains(slot.key) else { completion?(false); return }
        loadingInterstitials.insert(slot.key)
        AppLogger.log("📱 Loading interstitial[\(slot.key)]…")
        InterstitialAd.load(with: slot.adUnitID, request: Self.makeAdRequest(placement: slot.key)) { [weak self] ad, error in
            guard let self = self else { return }
            self.loadingInterstitials.remove(slot.key)
            if let error = error {
                AppLogger.log("❌ interstitial[\(slot.key)] load failed: \(error.localizedDescription)")
                completion?(false); return
            }
            ad?.fullScreenContentDelegate = self
            self.interstitials[slot.key] = ad
            AppLogger.log("✅ interstitial[\(slot.key)] loaded")
            completion?(true)
        }
    }

    /// Present a preloaded interstitial. `respectFrequency` (default true) enforces
    /// `interstitialMinInterval`; pass false for one-shots (splash/first-launch).
    /// `completion` always fires — after dismissal, or immediately if it can't show.
    public func showInterstitial(_ slot: AdSlot,
                                 from viewController: UIViewController? = nil,
                                 respectFrequency: Bool = true,
                                 completion: (() -> Void)? = nil) {
        guard expect(slot, .interstitial), !isSubscribedProvider() else { completion?(); return }

        if respectFrequency, let last = lastInterstitialShownAt,
           Date().timeIntervalSince(last) < interstitialMinInterval {
            AppLogger.log("❌ interstitial[\(slot.key)] gated (need \(interstitialMinInterval)s)")
            completion?(); return
        }
        guard !isShowingAd else { completion?(); return }
        guard let ad = interstitials[slot.key] else {
            AppLogger.log("❌ interstitial[\(slot.key)] not ready")
            preloadInterstitial(slot)
            completion?(); return
        }
        guard let presenter = viewController ?? UIApplication.shared.topViewController else { completion?(); return }

        interstitials[slot.key] = nil // consume
        AppAnalytics.logEvent("ad_" + slot.format.rawValue)
        if respectFrequency { lastInterstitialShownAt = Date() }

        let oid = ObjectIdentifier(ad)
        dismissCompletions[oid] = { [weak self] in
            self?.preloadInterstitial(slot) // refill for next time
            completion?()
        }
        ad.fullScreenContentDelegate = self
        isShowingAd = true
        ad.present(from: presenter)
        AppLogger.log("▶️ interstitial[\(slot.key)] shown")
    }

    // MARK: - Rewarded

    public func isRewardedReady(_ slot: AdSlot) -> Bool { rewardeds[slot.key] != nil }

    public func preloadRewarded(_ slot: AdSlot, completion: ((Bool) -> Void)? = nil) {
        guard expect(slot, .rewarded), !isSubscribedProvider() else { completion?(false); return }
        if rewardeds[slot.key] != nil { completion?(true); return }
        guard !loadingRewardeds.contains(slot.key) else { completion?(false); return }
        loadingRewardeds.insert(slot.key)
        AppLogger.log("📱 Loading rewarded[\(slot.key)]…")
        RewardedAd.load(with: slot.adUnitID, request: Self.makeAdRequest(placement: slot.key)) { [weak self] ad, error in
            guard let self = self else { return }
            self.loadingRewardeds.remove(slot.key)
            if let error = error {
                AppLogger.log("❌ rewarded[\(slot.key)] load failed: \(error.localizedDescription)")
                completion?(false); return
            }
            self.rewardeds[slot.key] = ad
            AppLogger.log("✅ rewarded[\(slot.key)] loaded")
            completion?(true)
        }
    }

    /// Present a preloaded rewarded ad. `completion(earned)` fires after dismissal
    /// (`true` if the reward was granted), or immediately with `false` if it can't show.
    public func showRewarded(_ slot: AdSlot,
                             from viewController: UIViewController,
                             completion: @escaping (Bool) -> Void) {
        guard expect(slot, .rewarded), !isSubscribedProvider() else { completion(false); return }
        guard !isShowingAd, let ad = rewardeds[slot.key] else {
            AppLogger.log("❌ rewarded[\(slot.key)] not ready / busy")
            completion(false); return
        }
        rewardeds[slot.key] = nil // consume
        AppAnalytics.logEvent("ad_" + slot.format.rawValue)

        let oid = ObjectIdentifier(ad)
        rewardCompletions[oid] = completion
        ad.fullScreenContentDelegate = self
        isShowingAd = true
        ad.present(from: viewController) { [weak self] in
            self?.rewardEarned.insert(oid)
        }
        AppLogger.log("▶️ rewarded[\(slot.key)] shown")
    }

    // MARK: - App Open

    public func isAppOpenReady(_ slot: AdSlot) -> Bool { appOpens[slot.key] != nil }

    public func preloadAppOpen(_ slot: AdSlot, completion: ((Bool) -> Void)? = nil) {
        guard expect(slot, .appOpen), !isSubscribedProvider() else { completion?(false); return }
        if appOpens[slot.key] != nil { completion?(true); return }
        guard !loadingAppOpens.contains(slot.key) else { completion?(false); return }
        loadingAppOpens.insert(slot.key)
        AppOpenAd.load(with: slot.adUnitID, request: Self.makeAdRequest(placement: slot.key)) { [weak self] ad, error in
            guard let self = self else { return }
            self.loadingAppOpens.remove(slot.key)
            if let error = error {
                AppLogger.log("❌ appOpen[\(slot.key)] load failed: \(error.localizedDescription)")
                completion?(false); return
            }
            self.appOpens[slot.key] = ad
            AppLogger.log("✅ appOpen[\(slot.key)] loaded")
            completion?(true)
        }
    }

    public func showAppOpen(_ slot: AdSlot,
                            from viewController: UIViewController? = nil,
                            completion: (() -> Void)? = nil) {
        guard expect(slot, .appOpen), !isSubscribedProvider() else { completion?(); return }
        guard !isShowingAd, let ad = appOpens[slot.key] else { completion?(); return }
        guard let presenter = viewController ?? UIApplication.shared.topViewController else { completion?(); return }
        appOpens[slot.key] = nil // consume
        AppAnalytics.logEvent("ad_" + slot.format.rawValue)
        let oid = ObjectIdentifier(ad)
        dismissCompletions[oid] = { completion?() }
        ad.fullScreenContentDelegate = self
        isShowingAd = true
        ad.present(from: presenter)
        AppLogger.log("▶️ appOpen[\(slot.key)] shown")
    }

    // MARK: - Banner

    /// Build a banner for a slot (adaptive inline). Caller owns layout.
    public func makeBanner(_ slot: AdSlot, rootViewController: UIViewController) -> BannerView? {
        guard expect(slot, .banner), !isSubscribedProvider() else { return nil }
        let size = currentOrientationInlineAdaptiveBanner(width: UIScreen.main.bounds.width)
        let banner = BannerView(adSize: size)
        banner.adUnitID = slot.adUnitID
        banner.rootViewController = rootViewController
        banner.load(Self.makeAdRequest(placement: slot.key))
        AppAnalytics.logEvent("ad_" + slot.format.rawValue)
        return banner
    }

    /// Build a banner for a slot and pin it to fill `view`. Clears `view`'s subviews first.
    @discardableResult
    public func loadBanner(_ slot: AdSlot, in viewController: UIViewController, into view: UIView) -> BannerView? {
        view.subviews.forEach { $0.removeFromSuperview() }
        guard let banner = makeBanner(slot, rootViewController: viewController) else { return nil }
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        return banner
    }

    // MARK: - Native

    /// Number of ready (cached) native ads for a slot.
    public func nativeReadyCount(_ slot: AdSlot) -> Int { nativePools[slot.key]?.count ?? 0 }

    /// Preload up to `count` native ads for a slot into its pool. `completion` fires
    /// once per loaded ad (ad on success, nil on failure).
    public func preloadNative(_ slot: AdSlot,
                              count: Int = 1,
                              from viewController: UIViewController? = nil,
                              completion: ((NativeAd?) -> Void)? = nil) {
        guard expect(slot, .native), !isSubscribedProvider() else { completion?(nil); return }
        guard let root = viewController ?? UIApplication.shared.sceneWindow?.rootViewController else {
            completion?(nil); return
        }
        let have = nativePools[slot.key]?.count ?? 0
        let inflight = nativeInFlight[slot.key] ?? 0
        let need = max(0, count - have - inflight)
        guard need > 0 else { completion?(nativePools[slot.key]?.first); return }
        for _ in 0..<need {
            nativeInFlight[slot.key, default: 0] += 1
            let loader = AdLoader(adUnitID: slot.adUnitID, rootViewController: root, adTypes: [.native], options: nil)
            loader.delegate = self
            nativeLoaders[loader] = (slot.key, completion)
            loader.load(Self.makeAdRequest(placement: slot.key))
        }
    }

    /// Pop one cached native ad for a slot (nil if none ready).
    public func getNative(_ slot: AdSlot) -> NativeAd? {
        guard var pool = nativePools[slot.key], !pool.isEmpty else { return nil }
        let ad = pool.removeFirst()
        nativePools[slot.key] = pool
        return ad
    }

    // MARK: - AdLoaderDelegate / NativeAdLoaderDelegate

    public func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        guard let (key, completion) = nativeLoaders[adLoader] else { return }
        nativeLoaders[adLoader] = nil
        nativeInFlight[key] = max(0, (nativeInFlight[key] ?? 1) - 1)
        nativePools[key, default: []].append(nativeAd)
        AppLogger.log("✅ native[\(key)] loaded (pool=\(nativePools[key]?.count ?? 0))")
        completion?(nativeAd)
    }

    public func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        guard let (key, completion) = nativeLoaders[adLoader] else { return }
        nativeLoaders[adLoader] = nil
        nativeInFlight[key] = max(0, (nativeInFlight[key] ?? 1) - 1)
        AppLogger.log("❌ native[\(key)] failed: \(error.localizedDescription)")
        completion?(nil)
    }

    public func adLoaderDidFinishLoading(_ adLoader: AdLoader) { /* no-op */ }
}

// MARK: - FullScreenContentDelegate
extension AdManager: FullScreenContentDelegate {
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isShowingAd = false
        let oid = ObjectIdentifier(ad)

        if let reward = rewardCompletions[oid] {
            let earned = rewardEarned.contains(oid)
            rewardCompletions[oid] = nil
            rewardEarned.remove(oid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { reward(earned) }
        }
        if let dismiss = dismissCompletions[oid] {
            dismissCompletions[oid] = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
        }
    }

    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        isShowingAd = false
        AppLogger.log("❌ Failed to present ad: \(error.localizedDescription)")
        let oid = ObjectIdentifier(ad)
        if let reward = rewardCompletions[oid] {
            rewardCompletions[oid] = nil
            rewardEarned.remove(oid)
            reward(false)
        }
        if let dismiss = dismissCompletions[oid] {
            dismissCompletions[oid] = nil
            dismiss()
        }
    }

    public func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        AppAnalytics.logEvent("custom_ad_impression")
    }
}
