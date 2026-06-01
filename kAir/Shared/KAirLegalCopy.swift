//
//  KAirLegalCopy.swift
//  kAir
//
//  Single-source legal / safety copy shared across features (Settings,
//  Onboarding, …). Centralized so the App Store 1.4.1 non-diagnostic disclaimer
//  and the privacy statement can never drift between the surfaces that show them.
//

import Foundation

enum KAirLegalCopy {
    /// App Store 1.4.1 non-diagnostic disclaimer. Surfaced anywhere kAir shows
    /// health information or AI health summaries.
    static let healthDisclaimer = """
    kAir is a wellness and information tool, not a medical device. It does not \
    diagnose, treat, or prevent any condition, and its AI summaries can be \
    incomplete or wrong. Always consult a qualified clinician for medical \
    decisions, and call your local emergency number in an emergency.
    """

    /// On-device privacy posture for the local-first v1.
    static let privacyStatement = """
    Your chats and Apple Health data are processed on this device. The assistant \
    runs on-device with Apple Foundation Models, so your prompts and health \
    context are not sent to kAir servers in this version.
    """
}
