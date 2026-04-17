//
//  PrivacyGuard.swift
//  Kair Health
//
//  Privacy and compliance policy surface for V1.
//

import Foundation

/// `PrivacyGuard` is the single policy surface that other modules should consult
/// before they access HealthKit data, combine that data with model context,
/// prepare exports, or touch any friend-facing transport.
///
/// This file intentionally defines boundaries and release-blocking rules only.
/// It does not contain UI, networking, or AI inference logic.
enum PrivacyGuard {}

extension PrivacyGuard {
    enum Decision: Equatable, Sendable {
        case allow
        case requireExplicitUserAction(reason: String)
        case deny(reason: String)
    }

    enum RuleID: String, CaseIterable, Sendable {
        case healthPurposeMustBeClear
        case healthReadMustBeMinimumNecessary
        case healthPermissionMustBeJustInTime
        case deniedHealthPermissionMustNotBeInferred
        case healthDataStaysOnDeviceByDefault
        case healthDataMustNotReachRemoteModel
        case healthDataMustNotReachFriendsTransport
        case healthDataMustNotBeUsedForAdsOrGrowth
        case healthDataMustNotBeStoredInICloud
        case healthAndSocialStoresMustRemainSeparate
        case exportMustBeUserInitiated
        case exportMustBePreviewed
        case offDeviceHealthSharingBlockedInV1
        case modelOutputsMustRemainNonDiagnostic
        case modelOutputsMustShowLimitations
    }

    enum HealthScope: String, CaseIterable, Sendable {
        case vitalSigns
        case sleep
        case activity
        case workouts
        case ecg
        case demographics
    }

    enum ModelSurface: String, CaseIterable, Sendable {
        case healthAnalysis
        case generalChat
        case friendsAssistant
        case exportPreparation
    }

    enum FriendPayloadType: String, CaseIterable, Sendable {
        case userProfile
        case invite
        case contactDiscovery
        case conversationMetadata
        case messageText
        case attachmentUpload
        case healthDataReference
        case healthSummary
        case healthRiskLabel
        case modelPrompt
        case modelOutput
    }

    enum ExportContent: String, CaseIterable, Sendable {
        case manualNote
        case friendConversation
        case rawHealthData
        case derivedHealthSummary
        case modelGeneratedRecommendation
        case reportBundle
    }

    enum ExportTarget: String, CaseIterable, Sendable {
        case onDeviceFile
        case systemShareSheet
        case friendsTransport
        case remoteAPI
    }

    struct Guardrail: Equatable, Sendable {
        let id: RuleID
        let summary: String
        let enforcementPoint: String
        let defaultDecision: Decision
        let releaseBlocking: Bool
    }

    /// V1 baseline policy.
    ///
    /// These rules are intentionally conservative and should be treated as
    /// release-blocking unless a later legal review explicitly narrows them.
    static let v1Guardrails: [Guardrail] = [
        Guardrail(
            id: .healthPurposeMustBeClear,
            summary: "HealthKit access is allowed only for clear health or fitness functionality that is visible in product copy and UI.",
            enforcementPoint: "Health permission request, App Store metadata, onboarding copy",
            defaultDecision: .deny(reason: "Do not request HealthKit access for generic chat, social discovery, growth, or unrelated product features."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .healthReadMustBeMinimumNecessary,
            summary: "Request only the minimum health scopes required for the current feature.",
            enforcementPoint: "HealthKit read scope definitions",
            defaultDecision: .requireExplicitUserAction(reason: "Each new health scope must be tied to a user-visible feature and justified before release."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .healthPermissionMustBeJustInTime,
            summary: "Health permissions must be requested in context, close to the feature that uses them.",
            enforcementPoint: "Permission orchestration",
            defaultDecision: .requireExplicitUserAction(reason: "Do not front-load broad health access on first launch without a feature-specific need."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .deniedHealthPermissionMustNotBeInferred,
            summary: "Missing HealthKit data must not be interpreted as refusal, risk, or a negative health signal.",
            enforcementPoint: "Analytics, scoring, empty-state logic",
            defaultDecision: .deny(reason: "HealthKit intentionally hides denied read permission; treat missing data as unknown."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .healthDataStaysOnDeviceByDefault,
            summary: "Raw and derived health data stay on device by default.",
            enforcementPoint: "Storage, sync, analytics, debugging, AI pipelines",
            defaultDecision: .allow,
            releaseBlocking: true
        ),
        Guardrail(
            id: .healthDataMustNotReachRemoteModel,
            summary: "HealthKit data, derived health summaries, prompts, embeddings, and risk labels must not reach any remote model transport in V1.",
            enforcementPoint: "Model provider routing",
            defaultDecision: .deny(reason: "V1 health analysis is local-only."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .healthDataMustNotReachFriendsTransport,
            summary: "Friends APIs must never receive HealthKit data or health-derived model output in V1.",
            enforcementPoint: "Friends service contract, serializers, sync jobs",
            defaultDecision: .deny(reason: "Social and health surfaces are strictly separated in V1."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .healthDataMustNotBeUsedForAdsOrGrowth,
            summary: "Health data and health-derived signals must not be used for advertising, marketing, growth experiments, ranking, or personalization outside health features.",
            enforcementPoint: "Analytics, experiments, notification targeting, lifecycle tooling",
            defaultDecision: .deny(reason: "Health data is purpose-limited to health management in V1."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .healthDataMustNotBeStoredInICloud,
            summary: "App-managed personal health information must not be stored in iCloud in V1.",
            enforcementPoint: "Persistence, backup policy, export storage",
            defaultDecision: .deny(reason: "Use on-device storage only and exclude health artifacts from cloud backup."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .healthAndSocialStoresMustRemainSeparate,
            summary: "Health storage, social storage, and model memory must remain logically and physically separate.",
            enforcementPoint: "Repository boundaries, caches, sync stores",
            defaultDecision: .deny(reason: "Do not reuse friend tables, chat memory, or shared caches for health content."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .exportMustBeUserInitiated,
            summary: "Any export of user content must be initiated by a deliberate user action.",
            enforcementPoint: "Export commands, background tasks, automation hooks",
            defaultDecision: .requireExplicitUserAction(reason: "No silent, scheduled, or automatic export."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .exportMustBePreviewed,
            summary: "Before any export leaves the health surface, the user must see what data categories and date range are included.",
            enforcementPoint: "Export preparation flow",
            defaultDecision: .requireExplicitUserAction(reason: "Preview and confirm before release."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .offDeviceHealthSharingBlockedInV1,
            summary: "Off-device sharing of HealthKit-derived content is blocked in V1 pending a separate legal review.",
            enforcementPoint: "Share sheet, remote upload, friends share flows",
            defaultDecision: .deny(reason: "V1 may support on-device export preparation only; no off-device health sharing path ships by default."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .modelOutputsMustRemainNonDiagnostic,
            summary: "Model output may summarize or explain trends, but must not diagnose, prescribe treatment, or claim medical certainty.",
            enforcementPoint: "Health copywriting, prompt templates, generated reports",
            defaultDecision: .deny(reason: "Escalate concerning findings to a clinician instead of presenting diagnosis or treatment advice."),
            releaseBlocking: true
        ),
        Guardrail(
            id: .modelOutputsMustShowLimitations,
            summary: "Health-facing model output must disclose that it is a local informational estimate and state material limitations when confidence or coverage is incomplete.",
            enforcementPoint: "Generated copy, reports, summaries",
            defaultDecision: .requireExplicitUserAction(reason: "Every material health interpretation needs a limitation or confidence statement."),
            releaseBlocking: true
        ),
    ]

    static let prohibitedFriendFields: Set<String> = [
        "healthData",
        "healthSummary",
        "healthSignals",
        "healthRiskLabel",
        "diagnosis",
        "condition",
        "medication",
        "symptom",
        "heartRate",
        "sleepAnalysis",
        "ecg",
        "biologicalSex",
        "dateOfBirth",
        "medicalNote",
        "modelHealthOutput",
        "healthPrompt",
        "healthEmbedding",
    ]

    static func guardrail(_ id: RuleID) -> Guardrail? {
        v1Guardrails.first(where: { $0.id == id })
    }
}
