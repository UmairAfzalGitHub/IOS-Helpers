//
//  AdSlot.swift
//  AdsKit (v2)
//
//  The package no longer names ad slots. Each app declares its OWN placements
//  as an enum conforming to `AdSlot` — as many of each format as it wants
//  (5 natives, 4 interstitials, 2 banners, …). Every placement carries its own
//  ad-unit id and its format, so `AdManager` can store and serve them generically,
//  keyed by `key`.
//
//  Example (in an app):
//
//      enum Ads: AdSlot {
//          case homeNative, resultNative, listNative
//          case genericInterstitial, exitInterstitial
//          case homeBanner, settingsBanner
//          case unlockRewarded
//          case appOpen
//
//          var adUnitID: String {
//              #if DEBUG
//              switch self { /* Google test ids per format */ }
//              #else
//              switch self { /* this app's live ids */ }
//              #endif
//          }
//          var format: AdFormat {
//              switch self {
//              case .homeNative, .resultNative, .listNative:      return .native
//              case .genericInterstitial, .exitInterstitial:      return .interstitial
//              case .homeBanner, .settingsBanner:                 return .banner
//              case .unlockRewarded:                              return .rewarded
//              case .appOpen:                                     return .appOpen
//              }
//          }
//      }
//

import Foundation

/// The ad formats AdManager knows how to load & present. `rawValue` doubles as
/// the analytics kind (`"ad_" + rawValue`), matching the legacy event names.
public enum AdFormat: String {
    case appOpen      = "appOpen_ad"
    case interstitial = "interstitial_ad"
    case rewarded     = "rewarded_ad"
    case banner       = "banner_ad"
    case native       = "native_ad"
}

/// One ad placement, defined by the host app. Conform an enum to this.
public protocol AdSlot {
    /// Stable identifier for this placement — used to key the cache and as an
    /// analytics tag. For `String` raw-value enums this is free (the case name).
    var key: String { get }
    /// The AdMob ad-unit id. The app decides test vs live (its own `#if DEBUG`).
    var adUnitID: String { get }
    /// Which format this placement is, so the manager loads/presents it correctly.
    var format: AdFormat { get }
}

public extension AdSlot where Self: RawRepresentable, Self.RawValue == String {
    /// Default key for `String`-backed enums: the case's raw value.
    var key: String { rawValue }
}
