//
//  AdsConsentManager.swift
//  AdsKit
//
//  ATT (App Tracking Transparency) + GDPR (Google UMP) consent orchestration.
//  App-agnostic: no per-app configuration. The host app's Info.plist supplies
//  `NSUserTrackingUsageDescription`; UMP is configured in the AdMob console.
//

import AppTrackingTransparency
import AdSupport
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import IOS_Helpers

public class AdsConsentManager {

    public static let shared = AdsConsentManager()

    private let gdprConsentKey = "GDPRConsentStatus"
    private init() {}

    private var consentForm: ConsentForm?

    // MARK: - Check ATT Consent
    public func requestATTConsent(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        AppLogger.log("User authorized tracking")
                        UserDefaults.standard.set(true, forKey: "consentSubmitted")
                        completion(true)
                    case .denied, .restricted, .notDetermined:
                        // Non-personalized ads (npa=1) are applied per-request via
                        // AdManager.makeAdRequest based on ATT status — nothing to
                        // register here.
                        AppLogger.log("ATT Not Authorized - Using Non-Personalized Ads")
                        UserDefaults.standard.set(true, forKey: "consentSubmitted")
                        completion(false)
                    @unknown default:
                        AppLogger.log("Unknown ATT status")
                        completion(false)
                    }
                }
            }
        }
    }

    // MARK: - Check GDPR Consent
    public func checkGDPRConsent(completion: @escaping () -> Void) {
        requestConsentInfoUpdate(completion: completion)
    }

    private func requestConsentInfoUpdate(completion: @escaping () -> Void) {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            if let error = error {
                AppLogger.log("❌ UMP consent info update failed: \(error.localizedDescription)")
                completion()
                return
            }

            self?.loadAndPresentConsentFormIfNeeded(completion: completion)
        }
    }

    private func loadAndPresentConsentFormIfNeeded(completion: @escaping () -> Void) {
        let consentInfo = ConsentInformation.shared

        guard consentInfo.formStatus == .available else {
            completion()
            return
        }

        ConsentForm.load { [weak self] form, error in
            if let error = error {
                AppLogger.log("❌ Failed to load UMP consent form: \(error.localizedDescription)")
                completion()
                return
            }

            guard let self = self, let form = form else {
                completion()
                return
            }

            self.consentForm = form
            self.presentConsentFormIfRequired(completion: completion)
        }
    }

    private func presentConsentFormIfRequired(completion: @escaping () -> Void) {
        let consentInfo = ConsentInformation.shared

        guard consentInfo.consentStatus == .required, let form = consentForm else {
            completion()
            return
        }

        DispatchQueue.main.async {
            guard let topController = UIApplication.shared.topViewController else {
                completion()
                return
            }

            form.present(from: topController) { [weak self] error in
                if let error = error {
                    AppLogger.log("❌ Failed to present UMP consent form: \(error.localizedDescription)")
                }

                self?.consentForm = nil

                if ConsentInformation.shared.consentStatus == .required {
                    self?.loadAndPresentConsentFormIfNeeded(completion: completion)
                } else {
                    completion()
                }
            }
        }
    }

    /// Clear consent (useful for testing or resetting the app)
    public func clearConsent() {
        UserDefaults.standard.removeObject(forKey: gdprConsentKey)
        ConsentInformation.shared.reset()
    }

    // MARK: - Ads State Check
    public func checkAdsState(completion: @escaping () -> Void) {
        requestATTConsent { isAuthorzed in
            if isAuthorzed {
                self.checkGDPRConsent {
                    completion()
                }
            } else {
                completion()
            }
        }
    }

    public func isGDPRApplicable() -> Bool {
        return ConsentInformation.shared.formStatus == .available
    }
}
