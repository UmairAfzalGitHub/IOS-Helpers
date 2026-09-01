# IOS-Helpers

Shared Swift package for our iOS apps. Centralizes the code that used to be
copy‑pasted per app — ad management, consent, Firebase analytics, and common
UIKit/Foundation helpers — so a fix or improvement lands in one place and every
app picks it up on its next version bump.

- **Repo:** https://github.com/UmairAfzalGitHub/IOS-Helpers
- **Platform:** iOS 15.0+
- **Tooling:** Swift 5.10 / Xcode 15+

---

## Products

The package exposes three libraries. Add only the ones an app needs.

| Product | What it is | Pulls in |
|---|---|---|
| **`IOS Helpers`** | Foundation/UIKit extensions, small UI controls, and `AppLogger`. Dependency‑free. | — |
| **`AnalyticsKit`** | `AppAnalytics` — one wrapper over Firebase Analytics + Crashlytics. | Firebase (Analytics, Crashlytics) |
| **`AdsKit`** | `AdManager` (banners / interstitials / rewarded / app‑open / native) + `AdsConsentManager` (ATT + UMP). | `IOS Helpers`, `AnalyticsKit`, GoogleMobileAds 13, UserMessagingPlatform 3 |

> `import` names: `import IOS_Helpers` (note the underscore — the module name has
> no spaces), `import AnalyticsKit`, `import AdsKit`.

---

## Versioning — read this first

Pin an **exact** version in every app:

```
Exact Version → 1.0.6
```

**Why exact, not "Up to Next Major":** the `1.0.x` tag line is *not* semver‑clean.
The current ads API ("v2", app‑defined placements) shipped as patch tags on the
`1.0.x` line, so `1.0.2` is the old model and `1.0.3`–`1.0.6` are the new one. An
`upToNextMajor`/range rule could therefore silently pull a change that breaks a
consuming app. Exact pins make every update deliberate: to move up, you change the
version number yourself and rebuild.

| Tag | What it is |
|---|---|
| `1.0.2` | Legacy fixed‑slot ads API (`AdConfiguration`) — do not use for new work |
| `1.0.6` | **Current** — generic `AdSlot` ads API + one‑shot refill fix + disable‑via‑empty‑id |

---

## Adding the package in Xcode

1. **File → Add Package Dependencies…**
2. URL: `https://github.com/UmairAfzalGitHub/IOS-Helpers`
3. Dependency Rule: **Exact Version** → `1.0.6`
4. Add the products your app needs to your app target (**General → Frameworks,
   Libraries, and Embedded Content**, or the Add‑Package products screen):
   - `AdsKit` (this also brings `AnalyticsKit`, `IOS Helpers`, GoogleMobileAds and
     UMP transitively — you do **not** add those separately)
   - `IOS Helpers` if you want the extensions/controls directly

To bump later: select IOS‑Helpers in **Package Dependencies**, change the exact
version, and resolve.

---

## AnalyticsKit

Firebase must be configured by the app (the package never ships a
`GoogleService-Info.plist`). Then log through `AppAnalytics`:

```swift
import AnalyticsKit

AppAnalytics.logEvent("open_home")                       // name-only funnel event
AppAnalytics.logEvent("purchase", parameters: ["sku": id])
AppAnalytics.setUserProperty("premium", forName: "tier")
AppAnalytics.record(error)                               // Crashlytics non-fatal
```

---

## AdsKit

### Model: you define the placements

The package does **not** name ad slots. Each app declares its own placements as an
enum conforming to `AdSlot` — **as many of each format as you want** (5 natives, 4
interstitials, 2 banners, …). Every placement carries its own ad‑unit id and its
format.

```swift
enum AdFormat { case appOpen, interstitial, rewarded, banner, native }

protocol AdSlot {
    var key: String { get }        // stable id — cache key + analytics tag
    var adUnitID: String { get }   // the AdMob unit id (app decides test vs live)
    var format: AdFormat { get }
}
```

A `String`‑backed enum gets `key` for free (the case name):

```swift
import AdsKit

enum Ads: String, AdSlot {
    case appOpen
    case splashInterstitial, exitInterstitial      // any number of interstitials
    case homeBanner, settingsBanner                // …banners
    case homeNative, resultNative, listNative      // …natives
    case unlockRewarded

    var format: AdsKit.AdFormat {                  // ⚠️ qualify as AdsKit.AdFormat (see Gotchas)
        switch self {
        case .appOpen:                              return .appOpen
        case .splashInterstitial, .exitInterstitial:return .interstitial
        case .homeBanner, .settingsBanner:          return .banner
        case .homeNative, .resultNative, .listNative:return .native
        case .unlockRewarded:                       return .rewarded
        }
    }

    var adUnitID: String {
        #if DEBUG   // Google's public test unit ids per format
        switch format {
        case .appOpen:      return "ca-app-pub-3940256099942544/5575463023"
        case .interstitial: return "ca-app-pub-3940256099942544/4411468910"
        case .rewarded:     return "ca-app-pub-3940256099942544/1712485313"
        case .banner:       return "ca-app-pub-3940256099942544/2934735716"
        case .native:       return "ca-app-pub-3940256099942544/3986624511"
        }
        #else       // this app's live ids, per case
        switch self {
        case .appOpen:              return "ca-app-pub-XXXX/…"
        // …one id per case…
        default:                    return ""
        }
        #endif
    }
}
```

### Launch wiring

```swift
// AppDelegate.didFinishLaunchingWithOptions
FirebaseApp.configure()                              // app owns Firebase init
AdManager.shared.configure(isSubscribed: { IAPManager.shared.isUserSubscribed })
```

```swift
// After your consent gate resolves (e.g. on the splash screen)
AdsConsentManager.shared.checkAdsState {             // ATT prompt + UMP/GDPR form
    AdManager.shared.setupAds()                      // starts the AdMob SDK (idempotent)
}
```

`setupAds()` starts the SDK and, once ready, logs a one‑line adapter health check:

```
📱 Mediation adapters: [GADMediationAdapterInMobi=READY, GADMediationAdapterVungle=READY, GADMobileAds=READY]
```

### API reference

All calls are no‑ops when the user is subscribed (per your `isSubscribed` closure)
or when the slot is disabled (see *Disabling a placement*). Present/refill logic
runs on the main thread — call these from the main thread.

**Interstitial**
```swift
AdManager.shared.preloadInterstitial(Ads.exitInterstitial) { ready in }
AdManager.shared.isInterstitialReady(Ads.exitInterstitial)
AdManager.shared.showInterstitial(Ads.exitInterstitial, from: self) { /* dismissed */ }
// one-shots (splash / first-launch) must always show, ignoring the frequency gate:
AdManager.shared.showInterstitial(Ads.splashInterstitial, from: self, respectFrequency: false) { }
```
- A recurring interstitial (`respectFrequency: true`, the default) auto‑reloads
  itself on dismiss so the next eligible show is ready, and is rate‑limited by
  `AdManager.shared.interstitialMinInterval` (default 30s, settable).
- A one‑shot (`respectFrequency: false`) shows regardless of the gate and does
  **not** auto‑reload.

**Rewarded**
```swift
AdManager.shared.preloadRewarded(Ads.unlockRewarded) { ready in }
AdManager.shared.showRewarded(Ads.unlockRewarded, from: self) { earned in
    if earned { /* grant reward */ }
}
```

**App Open**
```swift
AdManager.shared.preloadAppOpen(Ads.appOpen)          // e.g. on entering background
AdManager.shared.showAppOpen(Ads.appOpen)             // e.g. on next foreground
```

**Banner** (adaptive inline)
```swift
// Fill a container view (clears it first):
AdManager.shared.loadBanner(Ads.homeBanner, in: self, into: bannerContainerView)
// Or load into a banner view you already own (e.g. from a xib):
AdManager.shared.loadBanner(Ads.homeBanner, into: myBannerView, rootViewController: self)
// Or just build one and lay it out yourself:
let banner = AdManager.shared.makeBanner(Ads.homeBanner, rootViewController: self)
```

**Native** — two patterns:
```swift
// One-shot: load one and render it immediately (not cached)
AdManager.shared.loadNative(Ads.homeNative, from: self) { nativeAd in
    // render nativeAd (you build the NativeAdView)
}

// Pool: preload N, consume as needed (e.g. a list/feed)
AdManager.shared.preloadNative(Ads.resultNative, count: 3)
let ad = AdManager.shared.getNative(Ads.resultNative)   // pops one, nil if none ready
AdManager.shared.nativeReadyCount(Ads.resultNative)
```

### Disabling a placement (e.g. from Remote Config)

Return an **empty `adUnitID`** for a slot and every load/show for it becomes a
clean no‑op — no ad request, no failed‑load logs, no impact on the unit's stats.

```swift
var adUnitID: String {
    if self == .homeNative && !RemoteFlags.homeNativeEnabled { return "" } // dark
    #if DEBUG … #else … #endif
}
```

You can also check it: `AdManager.shared.isEnabled(Ads.homeNative)`.

---

## Mediation (optional)

AdMob mediation adapters are added as their own first‑party SPM packages — the
app must bundle the adapter for each network configured in its AdMob mediation
groups (configuring a network in the console alone is **not** enough).

| Network | Package URL | Product |
|---|---|---|
| Liftoff Monetize (Vungle) | `https://github.com/googleads/googleads-mobile-ios-mediation-liftoffmonetize` | `LiftoffMonetizeAdapterTarget` |
| Unity Ads | `https://github.com/googleads/googleads-mobile-ios-mediation-unity` | `UnityAdapterTarget` |
| InMobi | `https://github.com/googleads/googleads-mobile-ios-mediation-inmobi` | `InMobiAdapterTarget` |

Add the ones you need; they pull the network SDK + GoogleMobileAds transitively
(same GMA as AdsKit, no conflict). Some networks want a GDPR flag set at launch
(e.g. Vungle's `VunglePrivacySettings.setGDPRStatus(true)`). Verify adapters read
`READY` in the `setupAds()` log.

> **Do not** also install GoogleMobileAds via CocoaPods — two `GoogleMobileAds`
> modules (Pod + SPM) collide. This package is SPM‑only.

---

## App‑side checklist

- [ ] Add the package (Exact Version `1.0.6`) and link `AdsKit`.
- [ ] Add mediation adapter package(s) if the app uses mediation.
- [ ] Add `GoogleService-Info.plist` and call `FirebaseApp.configure()` at launch.
- [ ] `Info.plist`: `GADApplicationIdentifier`, `SKAdNetworkItems`,
      `NSUserTrackingUsageDescription`.
- [ ] Define an `Ads: AdSlot` enum with the app's placements + ids.
- [ ] At launch: `AdManager.shared.configure(isSubscribed:)`.
- [ ] After consent: `AdsConsentManager.shared.checkAdsState { AdManager.shared.setupAds() }`.
- [ ] Call the `preload*` / `show*` / `loadBanner` / `*Native` APIs per screen.
- [ ] Keep `IAPManager` (or your entitlement logic) in the app; feed it via the
      `isSubscribed` closure.

---

## Gotchas

- **`AdFormat` is ambiguous** in any file that imports both `AdsKit` and
  `GoogleMobileAds` (GMA also defines an `AdFormat`). Qualify it as
  `AdsKit.AdFormat` — e.g. in your `Ads` enum's `format` property.
- **Module import is `IOS_Helpers`** (underscore), because the target name has a
  space. `AdsKit` / `AnalyticsKit` import normally.
- **Firebase is app‑owned:** the package pulls the SDK but never configures it or
  ships a plist. Call `FirebaseApp.configure()` yourself.
- **iOS 15 minimum** (Firebase 12 / StoreKit 2 requirement).

---

## Not (yet) supported

These weren't needed by the first apps; add to the package when one requires them:

- **Banner sizes** — only adaptive inline. No MREC (300×250) or fixed 320×50 option yet.
- **Per‑placement interstitial frequency** — the rate limit is global across all interstitials.
- **Per‑placement analytics names** — ad events are logged per *format*
  (`ad_interstitial_ad`, …), not per slot. Log at the call site if you need finer granularity.
- **Rewarded‑interstitial** format.

---

## Logging

`AppLogger` (in `IOS Helpers`) prefixes every line with `App-Logs:` and is enabled
in DEBUG only by default:

```swift
import IOS_Helpers
AppLogger.log("something happened")
AppLogger.isEnabled = true   // force-enable in release if needed
```
