//
//  AdManager.swift
//  AdsKit
//
//  Shared AdMob manager (banners / interstitials / native / rewarded / app-open).
//  App-specific identity is injected, not hard-coded:
//    • ad-unit ids come from an `AdConfiguration` passed to `configure(_:isSubscribed:)`
//    • the "is the user subscribed?" check is an injected closure (each app keeps
//      its own IAPManager / entitlement logic)
//    • analytics go through `AppAnalytics` (AnalyticsKit → Firebase)
//

import Foundation
import GoogleMobileAds
import UIKit
import StoreKit
import IOS_Helpers
import AnalyticsKit
import AppTrackingTransparency
import CryptoKit

// MARK: - Ad Manager
public class AdManager: NSObject, AdLoaderDelegate, NativeAdLoaderDelegate {
    public static let shared = AdManager()

    // MARK: - Injected configuration

    /// Per-app ad-unit ids. Set once via `configure(_:isSubscribed:)` before any
    /// ad is loaded. Implicitly unwrapped because every load/show reads it and a
    /// missing configuration is a programmer error (the app must configure at launch).
    public private(set) var config: AdConfiguration!

    /// Returns whether the current user is subscribed (ads suppressed). Injected so
    /// AdsKit stays free of any particular IAP implementation. Defaults to `false`.
    private var isSubscribedProvider: () -> Bool = { false }

    /// Convenience read of the injected subscription state.
    public var isUserSubscribedNow: Bool { isSubscribedProvider() }

    /// Wire per-app ad identity and the subscription check into the shared manager.
    /// Call once at launch, before loading any ad.
    public func configure(_ configuration: AdConfiguration,
                          isSubscribed: @escaping () -> Bool = { false }) {
        self.config = configuration
        self.isSubscribedProvider = isSubscribed
    }

    // Ad Properties
    public var appOpenAd: AppOpenAd?
    public var interstitialAd: InterstitialAd?
    public var splashInterstitialAd: InterstitialAd?
    public var paywallInterstitialAd: InterstitialAd?
    public var rewardedAd: RewardedAd?
    private var nativeAdLoader: AdLoader?
    private var nativeAdCompletions: [AdLoader: (NativeAd?) -> Void] = [:]

    // State Management
    private var isLoadingAppOpenAd = false
    private var isLoadingInterstitial = false
    private var isLoadingSplashInterstitial = false
    private var isLoadingPaywallInterstitial = false
    public private(set) var didSplashInterstitialFailToLoad = false
    private var isLoadingRewarded = false

    /// Guards `setupAds()` against a second initialization (e.g. a re-entrant
    /// scene connect). The AdMob SDK only needs to start once per process.
    private var hasInitializedAds = false
    /// Monotonic timestamp captured when `MobileAds.shared.start` is invoked,
    /// used only to log SDK-init duration for diagnostics.
    private var splashSdkInitStartTime: CFTimeInterval = 0

    /// Whether `MobileAds.shared.start` has finished. Until this is `true` the SDK
    /// is still initializing and any `load(...)` request is dropped, so screens that
    /// want a fill (the onboarding banner, etc.) should gate on this. Splash blocks
    /// its hand-off on this so the whole app runs with a ready SDK.
    public private(set) var isSdkReady = false
    /// Callbacks queued while the SDK is still initializing, drained (once) the
    /// moment it becomes ready. Registered via `whenSdkReady(_:)`.
    private var sdkReadyCallbacks: [() -> Void] = []

    /// Runs `block` as soon as the AdMob SDK is initialized — immediately if it is
    /// already ready, otherwise when `MobileAds.shared.start` completes. Always
    /// invoked on the main queue.
    public func whenSdkReady(_ block: @escaping () -> Void) {
        if isSdkReady {
            DispatchQueue.main.async { block() }
        } else {
            sdkReadyCallbacks.append(block)
        }
    }

    /// Fired once when the splash interstitial finishes loading.
    public var onSplashInterstitialLoaded: (() -> Void)?
    /// Fired once when the splash interstitial load finishes with a failure
    /// (no-fill / error) so Splash can navigate immediately instead of waiting.
    public var onSplashInterstitialFailed: (() -> Void)?
    private var adDidDismissFullScreenContentCallback: (() -> Void)?
    private var adDidDismissRewardedCallback: ((Bool) -> Void)?
    private var didGetNativeAd: ((NativeAd?) -> Void)?

    private var splashBannerView: BannerView?
    private var isSplashBannerLoaded = false

    private var nativeAdPool: [NativeAd] = []
    private let maxNativeAds = 3
    private var shouldPrefetchNativeAds = true
    /// Number of pool native loads currently scheduled or in flight. Counted so
    /// overlapping `preloadNativeAds()` calls (splash + every `getNativeAd`) don't
    /// each schedule a fresh batch and overfill the pool past `maxNativeAds`.
    private var inFlightNativeLoads = 0

    // Dedicated one-shot native for the full-screen onboarding ad page. Kept in
    // its own slot (separate from the pool) so it is preloaded once and cached.
    private var onboardingFullScreenNativeAd: NativeAd?
    private var isLoadingOnboardingFullScreenNative = false

    /// True while the onboarding full-screen native load is in flight (not yet
    /// finished with success or failure). Lets Onboarding reserve the ad page for
    /// an ad that is about to arrive, instead of dropping a load that finishes a
    /// beat after `viewDidLoad`.
    public var isOnboardingFullScreenNativeInFlight: Bool { isLoadingOnboardingFullScreenNative }

    /// One-shot callback fired when the onboarding full-screen native load finishes
    /// — with the ad on success, or `nil` on failure. Onboarding registers this
    /// when it reserved the ad page while the load was still in flight, so it can
    /// populate the page the moment the ad lands (recovering the load→show race).
    public var onOnboardingFullScreenNativeReady: ((NativeAd?) -> Void)?

    // Dedicated one-shot native for the Language screen's first ad (shown on
    // screen load). Preloaded before the screen appears so it is visible
    // immediately, in its own slot separate from the pool.
    private var languageNativeAd: NativeAd?
    private var isLoadingLanguageNative = false

    public var isRewardGranted = false
    public var avilableNativeAd: NativeAd?
    public var isShowingAd = false
    public var splashInterstitial = true
    public var onboardingReviewEnabled = false
    public var showRewardedAdScreen: Bool = true

    /// Minimum time that must elapse between two generic interstitials. Replaces
    /// the old tap-counter gate — an interstitial can show at most once every
    /// `interstitialMinInterval` seconds. Splash & paywall interstitials are
    /// exempt: they are one-shot per session and go through their own show
    /// methods, which never consult this gate.
    public var interstitialMinInterval: TimeInterval = 30
    /// When the last generic interstitial was dismissed. `nil` until the first
    /// one is shown, so the first eligible request always passes the gate.
    private var lastInterstitialShownAt: Date?

    private override init() {
        super.init()
    }

    // MARK: - Setup
    public func setupAds() {
        guard !hasInitializedAds else { return }
        hasInitializedAds = true
        AppLogger.log("📱 Setting up AdMob...")

        #if DEBUG
        // Register this device as an AdMob test device so DEBUG builds always get
        // test fills. The hash AdMob expects is the MD5 of the uppercased IDFV.
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? "nil"
        let idfvHash = Self.md5Hex(idfv.uppercased())
        AppLogger.log("📱 IDFV: \(idfv)")
        AppLogger.log("📱 IDFV MD5 (AdMob test device hash): \(idfvHash)")
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "GADSimulatorID",
            idfvHash
        ]
        #endif

        splashSdkInitStartTime = CACurrentMediaTime()
        AppLogger.log("[SplashAdTiming] SDK_INIT_START — calling MobileAds.shared.start")
        MobileAds.shared.start { [weak self] status in
            guard let self = self else { return }
            let sdkInitElapsed = CACurrentMediaTime() - self.splashSdkInitStartTime
            AppLogger.log(String(format: "[SplashAdTiming] SDK_INIT_DONE — completion after %.2fs", sdkInitElapsed))
            AppLogger.log("📱 AdMob SDK initialization completed with status: \(status)")
            // One-line mediation adapter health check: each adapter's ready/not-ready
            // state (Vungle/Unity/… only report READY once their SDK has initialized).
            let adapterSummary = status.adapterStatusesByClassName
                .map { "\($0.key.components(separatedBy: ".").last ?? $0.key)=\($0.value.state == .ready ? "READY" : "NOT_READY")" }
                .sorted()
                .joined(separator: ", ")
            AppLogger.log("📱 Mediation adapters: [\(adapterSummary)]")
            // Mark the SDK ready and drain anything that was waiting on it (splash
            // hand-off, onboarding banner, …). Do this before kicking off loads so
            // those waiters see a ready SDK.
            self.isSdkReady = true
            let readyCallbacks = self.sdkReadyCallbacks
            self.sdkReadyCallbacks.removeAll()
            for callback in readyCallbacks { callback() }
            // App Open ad is no longer loaded here. It is loaded when the app
            // enters the background (see SceneDelegate.sceneDidEnterBackground), so
            // it is fresh and ready to show on the next foreground — and we don't
            // load one at launch that the splash interstitial preempts (which was
            // dragging the App Open show rate down).
            self.loadSplashInterstitialAd()
            // The generic interstitial is NOT preloaded at launch. It is never shown
            // during splash/onboarding/language — only on Home and later feature
            // screens — so preloading it here meant every session paid a load that
            // sat idle (and often expired unshown) through the whole pre-Home flow,
            // dragging the interstitial show rate down. It is now loaded in
            // HomeViewController.viewDidLoad (the first screen that can show it), and
            // still self-heals on demand via showInterstitial.
            // Note: the splash banner is loaded by SplashViewController itself,
            // only after ATT/consent resolves (see SplashViewController.setupBanner),
            // so it never loads behind the ATT prompt.
        }
    }

    /// Builds an ad request, attaching the non-personalized-ads flag (npa=1)
    /// whenever the user has NOT authorized tracking (ATT). Every ad load in the
    /// app goes through this so the flag actually reaches the request —
    /// registering `npa` on a throwaway request has no effect.
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
        let digest = Insecure.MD5.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    #endif

    /// StoreKit 2 entitlement check — true if any auto-renewable subscription is
    /// currently active. Separate from the injected `isSubscribedProvider`; apps
    /// can use this to feed their own entitlement store.
    public func isUserSubscribed() async -> Bool {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productType == .autoRenewable {
                    return true
                }
            case .unverified:
                continue
            }
        }
        return false
    }

    public func checkSubscriptionAndSave() async {
        let subscribed = await isUserSubscribed()
        UserDefaults.standard.set(subscribed, forKey: "isUserSubscribed")
    }

    // MARK: - App Open Ads

    public func loadAppOpenAd() {
        guard !isSubscribedProvider() else { return }
        guard appOpenAd == nil else { return } // don't reload while one is already waiting
        guard !isLoadingAppOpenAd else { return }
        isLoadingAppOpenAd = true

        AppOpenAd.load(with: config.appOpen.adId,
                       request: Self.makeAdRequest(placement: "app_open")) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoadingAppOpenAd = false

            if let error = error {
                AppLogger.log("❌ Failed to load app open ad: \(error.localizedDescription)")
                return
            }
            AppLogger.log("✅ App Open ad loaded successfully")
            self.appOpenAd = ad
        }
    }

    public func showAppOpenAd() {
        guard !isSubscribedProvider() else { return }
        guard let appOpenAd = self.appOpenAd, !self.isShowingAd else { return }
        guard shouldShowAd() else { return }

        appOpenAd.fullScreenContentDelegate = self
        appOpenAd.present(from: UIApplication.shared.topViewController!)
        self.isShowingAd = true
        self.appOpenAd = nil // consumed — the next background load refills it
        AppLogger.log("▶️ App Open Ad shown successfully")
    }

    public func shouldShowAd() -> Bool {
        let defaults = UserDefaults.standard
        let currentTime = Date().timeIntervalSince1970 // Get current time in seconds

        // Retrieve last ad time
        let lastAdTime = defaults.double(forKey: "LastAdTime")

        // If lastAdTime is 0, it means no ad was shown before, so show the ad
        if lastAdTime > 0 {
            let timeSinceLastAd = currentTime - lastAdTime

            AppLogger.log("timeSinceLastAd: \(timeSinceLastAd)")
            // Check if 5 seconds have passed since the last ad
            if timeSinceLastAd < 5 {
                AppLogger.log("Ad was shown \(timeSinceLastAd) seconds ago. Not showing ad.")
                return false
            }
        }

        // Save current time as last ad shown time
        defaults.set(currentTime, forKey: "LastAdTime")

        AppLogger.log("Showing ad now.")
        return true
    }

    // MARK: - Interstitial Ads
    public func loadInterstitialAd(id: AdMobId, completion: ((Bool?, InterstitialAd?) -> Void)? = nil) {
        guard !isSubscribedProvider() else { return }
        // An interstitial is already loaded and waiting — don't fetch a second one
        // (that would discard the ready ad as an unshown load and tank show rate).
        // Hand the waiting ad straight to the caller so its show flow proceeds.
        if let interstitialAd = interstitialAd {
            completion?(true, interstitialAd)
            return
        }
        guard !isLoadingInterstitial else { return }
        isLoadingInterstitial = true
        AppLogger.log("📱 Loading Interstitial Ad...")

        InterstitialAd.load(with: id.adId,
                            request: Self.makeAdRequest(placement: id.analyticsId.rawValue)) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoadingInterstitial = false

            if let error = error {
                AppLogger.log("❌ Failed to load interstitial ad: \(error.localizedDescription)")
                completion?(false, nil)
                return
            }
            AppLogger.log("✅ Interstitial ad loaded successfully")
            self.interstitialAd = ad
            self.interstitialAd?.fullScreenContentDelegate = self
            completion?(true, ad)
        }
    }

    public func showInterstitial(adId: AdMobId, from viewController: UIViewController? = nil, completion: (() -> Void)? = nil) {
        guard !isSubscribedProvider() else { completion?(); return }

        // Time gate: at most one generic interstitial every `interstitialMinInterval`
        // seconds (measured from the previous one's dismissal). Splash & paywall
        // interstitials are exempt and never reach this method.
        if let lastShown = lastInterstitialShownAt,
           Date().timeIntervalSince(lastShown) < interstitialMinInterval {
            AppLogger.log("❌ Interstitial gap not elapsed (need \(interstitialMinInterval)s)")
            // Do NOT reload here — an ad is already loaded and waiting for the next
            // eligible tap. Reloading would discard it as an unshown load.
            completion?()
            return
        }

        guard !isShowingAd else {
            AppLogger.log("❌ Interstitial Ad cannot be shown because an ad is already being displayed")
            // Same as above: keep the waiting ad, don't reload.
            completion?()
            return
        }

        guard let interstitialAd = interstitialAd else {
            AppLogger.log("❌ Interstitial Ad is not available")
            loadInterstitialAd(id: adId) // preload so the next eligible tap can show one
            completion?()
            return
        }

        // analytics
        AppAnalytics.logEvent("ad_" + adId.analyticsId.rawValue)

        interstitialAd.fullScreenContentDelegate = self
        interstitialAd.present(from: viewController)
        isShowingAd = true
        AppLogger.log("▶️ Interstitial Ad shown successfully")

        // Call the completion block after the ad is dismissed
        adDidDismissFullScreenContentCallback = completion
    }

    // MARK: - Splash Interstitial (one-shot, splash only)
    /// Preloaded once during `setupAds()` so it is ready by the time the splash
    /// finishes. Kept in its own slot — decoupled from the generic interstitial
    /// and its `adCounter` frequency gate.
    public func loadSplashInterstitialAd() {
        guard !isSubscribedProvider() else { return }
        guard splashInterstitial else { return } // remote enable flag
        guard !isLoadingSplashInterstitial else { return }
        isLoadingSplashInterstitial = true
        didSplashInterstitialFailToLoad = false
        AppLogger.log("📱 Loading Splash Interstitial Ad...")

        InterstitialAd.load(with: config.splashInterstitial.adId,
                            request: Self.makeAdRequest(placement: "splash_interstitial")) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoadingSplashInterstitial = false

            if let error = error {
                AppLogger.log("❌ Splash interstitial load failed: \(error.localizedDescription)")
                self.didSplashInterstitialFailToLoad = true
                let failHandler = self.onSplashInterstitialFailed
                self.onSplashInterstitialLoaded = nil
                self.onSplashInterstitialFailed = nil
                failHandler?()
                return
            }
            AppLogger.log("✅ Splash interstitial loaded")
            self.splashInterstitialAd = ad
            self.splashInterstitialAd?.fullScreenContentDelegate = self
            let loadHandler = self.onSplashInterstitialLoaded
            self.onSplashInterstitialLoaded = nil
            self.onSplashInterstitialFailed = nil
            loadHandler?()
        }
    }

    public func showSplashInterstitial(from viewController: UIViewController? = nil, completion: (() -> Void)? = nil) {
        guard !isSubscribedProvider() else {
            AppLogger.log("⛔️ showSplashInterstitial skipped: user subscribed")
            completion?(); return
        }
        guard let ad = splashInterstitialAd, !isShowingAd else {
            AppLogger.log("⛔️ showSplashInterstitial skipped: ad=\(splashInterstitialAd == nil ? "nil" : "ready"), isShowingAd=\(isShowingAd)")
            completion?(); return
        }
        guard let presenting = viewController ?? UIApplication.shared.topViewController else {
            AppLogger.log("⛔️ showSplashInterstitial skipped: no presenting VC")
            completion?(); return
        }

        // analytics
        AppAnalytics.logEvent("ad_" + config.splashInterstitial.analyticsId.rawValue)

        ad.fullScreenContentDelegate = self
        ad.present(from: presenting)
        isShowingAd = true
        adDidDismissFullScreenContentCallback = completion
        AppLogger.log("▶️ Splash interstitial shown")
    }

    // MARK: - Paywall Interstitial (one-shot, shown when the home paywall is closed)
    /// Preloaded while the home paywall is on screen so it is ready by the time the
    /// user taps the paywall's close button. Kept in its own slot — decoupled from
    /// the generic interstitial and its `adCounter` frequency gate.
    public func loadPaywallInterstitialAd() {
        guard !isSubscribedProvider() else { return }
        guard !isLoadingPaywallInterstitial else { return }
        isLoadingPaywallInterstitial = true
        AppLogger.log("📱 Loading Paywall Interstitial Ad...")

        InterstitialAd.load(with: config.paywallInterstitial.adId,
                            request: Self.makeAdRequest(placement: "paywall_interstitial")) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoadingPaywallInterstitial = false

            if let error = error {
                AppLogger.log("❌ Paywall interstitial load failed: \(error.localizedDescription)")
                return
            }
            AppLogger.log("✅ Paywall interstitial loaded")
            self.paywallInterstitialAd = ad
            self.paywallInterstitialAd?.fullScreenContentDelegate = self
        }
    }

    /// Shows the preloaded paywall interstitial. The completion always fires —
    /// after the ad is dismissed, or immediately if no ad is available — so the
    /// caller can continue its flow (e.g. request notification permission).
    public func showPaywallInterstitial(from viewController: UIViewController? = nil, completion: (() -> Void)? = nil) {
        guard !isSubscribedProvider() else { completion?(); return }
        guard let ad = paywallInterstitialAd, !isShowingAd else { completion?(); return }
        guard let presenting = viewController ?? UIApplication.shared.topViewController else {
            completion?(); return
        }

        // analytics
        AppAnalytics.logEvent("ad_" + config.paywallInterstitial.analyticsId.rawValue)

        ad.fullScreenContentDelegate = self
        ad.present(from: presenting)
        isShowingAd = true
        adDidDismissFullScreenContentCallback = completion
        AppLogger.log("▶️ Paywall interstitial shown")
    }

    // MARK: - Rewarded Ads
    public func loadRewardedAd(id: AdMobId, completion: ((Bool?) -> Void)? = nil) {
        guard !isSubscribedProvider() else { return }
        guard !isLoadingRewarded else { return }

        isLoadingRewarded = true
        AppLogger.log("📱 Loading Rewarded Ad...")

        RewardedAd.load(with: id.adId,
                        request: Self.makeAdRequest(placement: id.analyticsId.rawValue)) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoadingRewarded = false

            if let error = error {
                AppLogger.log("❌ Failed to load rewarded ad: \(error.localizedDescription)")
                completion?(false)
                return
            }
            AppLogger.log("✅ Rewarded ad loaded successfully")
            self.rewardedAd = ad
            completion?(true)
        }
    }

    public func showRewardedAd(adId: AdMobId, from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let rewardedAd = rewardedAd else {
            AppLogger.log("❌ Rewarded Ad is not available")
            completion(false)
            return
        }

        guard !isShowingAd else {
            AppLogger.log("❌ Rewarded Ad cannot be shown because an ad is already being displayed")
            completion(false)
            return
        }

        // analytics
        AppAnalytics.logEvent("ad_" + adId.analyticsId.rawValue)

        self.adDidDismissRewardedCallback = completion
        rewardedAd.fullScreenContentDelegate = self
        rewardedAd.present(from: viewController) { [weak self] in
            self?.isRewardGranted = true
        }
        isShowingAd = true
        AppLogger.log("▶️ Rewarded Ad shown successfully")
    }

    // MARK: - Banner Ads

    public func loadbannerAd(adId: AdMobId, bannerView: BannerView?, root: UIViewController) {
        guard !isSubscribedProvider() else { return }
        bannerView?.adUnitID = adId.adId
        bannerView?.rootViewController = root
        bannerView?.load(Self.makeAdRequest(placement: adId.analyticsId.rawValue))
        // analytics
        AppAnalytics.logEvent("ad_" + adId.analyticsId.rawValue)
    }

    public func preloadSplashBanner(adID: String) {
        guard !isSubscribedProvider() else { return }
        AppLogger.log("📱 Preloading Splash Banner...")
        let screenWidth = UIScreen.main.bounds.width
        let adSize = currentOrientationInlineAdaptiveBanner(width: screenWidth)
        splashBannerView = BannerView(adSize: adSize)
        splashBannerView?.adUnitID = adID
        splashBannerView?.load(Self.makeAdRequest(placement: "splash_banner"))
    }

    public func getSplashBanner(for viewController: UIViewController) -> BannerView? {
        guard !isSubscribedProvider() else { return nil }
        splashBannerView?.rootViewController = viewController
        let banner = splashBannerView
        // We don't null it out here because we might need it if viewWillAppear is called multiple times,
        // but typically for splash it's one-off.
        return banner
    }

    // MARK: - Adaptive Inline Banner
    public func createInlineBanner(in viewController: UIViewController, adID: String) -> BannerView {
        let screenWidth = UIScreen.main.bounds.width
        let adSize = currentOrientationInlineAdaptiveBanner(width: screenWidth)

        let bannerView = BannerView(adSize: adSize)

        bannerView.adUnitID = adID
        bannerView.rootViewController = viewController
        bannerView.load(Self.makeAdRequest(placement: "banner"))
        return bannerView
    }

    @discardableResult
    public func loadBanner(in viewController: UIViewController, into view: UIView, adID: String) -> BannerView? {
        // Clear previous ads if any
        view.subviews.forEach { $0.removeFromSuperview() }

        guard !isSubscribedProvider() else { return nil }

        let bannerView = createInlineBanner(in: viewController, adID: adID)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)

        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        return bannerView
    }

    // MARK: - Native Ads

    public func preloadNativeAds() {
        guard let root = UIApplication.shared.sceneWindow?.rootViewController else { return }

        // Only load the deficit that isn't already covered by the pool OR by loads
        // already scheduled/in flight. Without subtracting `inFlightNativeLoads`,
        // overlapping calls (splash + every getNativeAd) each schedule a full batch
        // and the pool overfills past maxNativeAds (seen in logs growing to 6).
        let deficit = maxNativeAds - nativeAdPool.count - inFlightNativeLoads
        guard deficit > 0 else { return }

        // Load sequentially with increasing delays to avoid overwhelming the ad network.
        for index in 0..<deficit {
            // Reserve the slot synchronously so a concurrent call sees it immediately.
            inFlightNativeLoads += 1
            let delay = 2.0 * Double(index + 1)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }

                self.loadNativeAd(adId: self.config.native, from: root, placement: "pool") { [weak self] ad in
                    guard let self = self else { return }
                    self.inFlightNativeLoads = max(0, self.inFlightNativeLoads - 1)

                    // Cap the pool — a late-arriving ad from a batch scheduled
                    // before some other batch filled the pool must not overflow it.
                    if let ad = ad, self.nativeAdPool.count < self.maxNativeAds {
                        self.nativeAdPool.append(ad)
                    }
                }
            }
        }
    }

    public func getNativeAd(stopPrefetch: Bool = false) -> NativeAd? {
        if stopPrefetch {
            shouldPrefetchNativeAds = false
        }
        if !nativeAdPool.isEmpty {
            let ad = nativeAdPool.removeFirst()
            if shouldPrefetchNativeAds {
                preloadNativeAds()
            }
            return ad
        }
        if shouldPrefetchNativeAds {
            preloadNativeAds()
        }
        return nil
    }

    public func resumeNativeAdPrefetch() {
        shouldPrefetchNativeAds = true
        preloadNativeAds()
    }

    // MARK: - Onboarding Full-Screen Native (one-shot, preloaded)

    /// Preloads the dedicated full-screen onboarding native so it is cached by
    /// the time onboarding builds its pages. Idempotent — a second call while a
    /// load is in flight or an ad is already cached is a no-op.
    public func preloadOnboardingFullScreenNativeAd() {
        guard !isSubscribedProvider() else { return }
        guard onboardingFullScreenNativeAd == nil, !isLoadingOnboardingFullScreenNative else { return }
        guard let root = UIApplication.shared.sceneWindow?.rootViewController else { return }
        isLoadingOnboardingFullScreenNative = true
        loadNativeAd(adId: config.onboardingFullScreenNative, from: root, placement: "onboarding_fullscreen") { [weak self] ad in
            guard let self = self else { return }
            self.isLoadingOnboardingFullScreenNative = false
            if let ad = ad {
                self.onboardingFullScreenNativeAd = ad
            }
            // Notify a waiting Onboarding screen (if it reserved the page while this
            // load was in flight) so it can show a late-arriving ad instead of
            // discarding it. Fires once, then clears.
            let readyHandler = self.onOnboardingFullScreenNativeReady
            self.onOnboardingFullScreenNativeReady = nil
            readyHandler?(ad)
        }
    }

    /// The cached full-screen onboarding native, if one preloaded in time.
    public func cachedOnboardingFullScreenNativeAd() -> NativeAd? {
        return onboardingFullScreenNativeAd
    }

    /// Returns the cached full-screen onboarding native and clears the slot.
    @discardableResult
    public func consumeOnboardingFullScreenNativeAd() -> NativeAd? {
        let ad = onboardingFullScreenNativeAd
        onboardingFullScreenNativeAd = nil
        return ad
    }

    // MARK: - Language Screen Native (one-shot, preloaded)

    /// Preloads the Language screen's first native so it is cached before the
    /// screen appears and can be shown immediately on load. Idempotent — a
    /// second call while a load is in flight or an ad is already cached is a
    /// no-op.
    public func preloadLanguageNativeAd() {
        guard !isSubscribedProvider() else { return }
        guard languageNativeAd == nil, !isLoadingLanguageNative else { return }
        guard let root = UIApplication.shared.sceneWindow?.rootViewController else { return }
        isLoadingLanguageNative = true
        AppLogger.log("📱 Preloading language native...")
        loadNativeAd(adId: config.languageNative1, from: root, placement: "language") { [weak self] ad in
            guard let self = self else { return }
            self.isLoadingLanguageNative = false
            if let ad = ad {
                AppLogger.log("✅ Language native loaded")
                self.languageNativeAd = ad
            } else {
                AppLogger.log("❌ Language native failed to load")
            }
        }
    }

    /// Returns the cached Language native and clears the slot.
    @discardableResult
    public func consumeLanguageNativeAd() -> NativeAd? {
        let ad = languageNativeAd
        languageNativeAd = nil
        return ad
    }

    /// - Parameter placement: human-readable slot name ("onboarding_fullscreen",
    ///   "pool", "country", "language", …) used only for logging. In DEBUG every
    ///   native shares the same Google test unit, so the unit id can't tell them
    ///   apart — this label tags the ad request per slot.
    public func loadNativeAd(adId: AdMobId, from viewController: UIViewController,
                             placement: String = "native",
                             completion: ((GoogleMobileAds.NativeAd?) -> Void)?) {
        guard !isSubscribedProvider() else { return }

        let googleAdLoader = GoogleMobileAds.AdLoader(adUnitID: adId.adId,
                                                      rootViewController: viewController,
                                                      adTypes: [.native],
                                                      options: nil)
        googleAdLoader.delegate = self
        self.nativeAdCompletions[googleAdLoader] = completion
        googleAdLoader.load(Self.makeAdRequest(placement: placement))
        self.nativeAdLoader = googleAdLoader
    }
}

// MARK: - GADFullScreenContentDelegate
extension AdManager: FullScreenContentDelegate {
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isShowingAd = false

        // Identify which slot actually dismissed. Only that slot should be reset
        // and refilled — resetting a slot that didn't dismiss discards an
        // already-loaded (already-counted) ad without ever showing it, which is
        // what was tanking the interstitial show rate: App Open / splash / paywall
        // dismissals were nil-ing and re-requesting the waiting generic interstitial
        // on every foreground cycle, inflating loads with no matching shows.
        let wasGenericInterstitial = (ad === interstitialAd)
        let wasSplashInterstitial = (ad === splashInterstitialAd)
        let wasPaywallInterstitial = (ad === paywallInterstitialAd)
        let wasRewarded = (ad === rewardedAd)

        // Only the generic interstitial participates in the 30s gate. Stamp the
        // dismissal time so the next one can't show until the interval elapses.
        // (Splash & paywall interstitials are exempt — they must not start the clock.)
        if wasGenericInterstitial {
            lastInterstitialShownAt = Date()
        }

        // Clear only the slot that was actually consumed. The other slots keep any
        // preloaded ad they already hold.
        if wasSplashInterstitial { splashInterstitialAd = nil }
        if wasPaywallInterstitial { paywallInterstitialAd = nil }
        if wasRewarded { rewardedAd = nil }

        // Refill the generic interstitial ONLY when a generic interstitial was the
        // ad that just dismissed (i.e. we actually consumed it). App Open, splash,
        // paywall and rewarded dismissals leave the waiting generic interstitial
        // untouched so it can still be shown on the next eligible tap.
        if wasGenericInterstitial {
            interstitialAd = nil
            // Preload the next generic interstitial so it's ready for the following
            // eligible tap once the interval has elapsed.
            loadInterstitialAd(id: config.interstitial)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            self.adDidDismissFullScreenContentCallback?()
            self.adDidDismissRewardedCallback?(self.isRewardGranted)

            self.adDidDismissFullScreenContentCallback = nil
            self.adDidDismissRewardedCallback = nil
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
            self.isRewardGranted = false
        })
    }

    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        isShowingAd = false
        AppLogger.log("❌ Failed to present ad: \(error.localizedDescription)")
    }

    // MARK: - NativeAdLoaderDelegate

    public func adLoader(_ adLoader: GoogleMobileAds.AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        avilableNativeAd = nativeAd
        // Use the completion from our dictionary instead of the global property
        if let completion = nativeAdCompletions[adLoader] {
            completion(nativeAd)
        }
        nativeAdCompletions[adLoader] = nil
    }

    public func adLoader(_ adLoader: GoogleMobileAds.AdLoader, didFailToReceiveAdWithError error: Error) {
        if let completion = nativeAdCompletions[adLoader] {
            completion(nil)
        }
        nativeAdCompletions[adLoader] = nil
    }

    public func adLoaderDidFinishLoading(_ adLoader: GoogleMobileAds.AdLoader) {
        // no-op (kept for protocol conformance).
    }

    public func adDidRecordImpression(_ ad: any GoogleMobileAds.FullScreenPresentingAd) {
        AppAnalytics.logEvent("custom_ad_impression")
    }
}
