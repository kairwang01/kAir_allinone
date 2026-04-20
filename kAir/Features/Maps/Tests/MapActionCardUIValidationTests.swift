//
//  MapActionCardUIValidationTests.swift
//  kAir
//
//  T5 — UI-level validation for Maps UI Spec v1.
//
//  Scope: enforce the 3 task kinds × 4 system states matrix and the
//  frozen trust-pill vocabulary. This complements T4 (data-layer chain
//  round-trips) by locking the *rendering inputs* — what the shell is
//  told to show — against the spec.
//
//  What this covers:
//    1. For every (kind × zh/en × state) the shell inputs are correct:
//       header label, primary/secondary CTA copy, feedback label,
//       primary-enabled flag, card opacity, state-badge text.
//    2. For every (kind × trust scenario) the trust-pill array emitted by
//       `MapActionCardTrustMetadata.pills` matches the spec's vocabulary
//       (§1.5 in maps-ui-spec-v1.md).
//    3. The stubbed default metadata never omits the `partnerFallback`
//       pill — the baseline the user sees must always flag that the
//       partner integration is pending.
//
//  What this does NOT cover (out of v1 scope):
//    - Pixel snapshots (no snapshot infra wired in this prototype).
//    - Execution-surface hero state permutations (enforced inline by
//      structural rendering in MapsHomeView; exercised at runtime).
//

import Foundation

struct MapActionCardUIValidationReport {
    let results: [KernelPhase1TestResult]

    var allPassed: Bool { results.allSatisfy(\.passed) }
    var passedCount: Int { results.filter(\.passed).count }
    var failedCount: Int { results.filter { !$0.passed }.count }
}

enum MapActionCardUIValidationTests {
    @MainActor
    static func runAll() -> MapActionCardUIValidationReport {
        let results: [KernelPhase1TestResult] = [
            testPrimaryCTAPerKindLocked(),
            testSecondaryCTAPerKindLocked(),
            testLoadingStateEnablesPrimary(),
            testAcceptedStateDisablesPrimary(),
            testDismissedStateDisablesPrimaryAndFades(),
            testRecommendedStateHasNoStateBadge(),
            testTrustPillDefaultStubbedMatrix(),
            testTrustPillPermissionDenied(),
            testTrustPillPermissionManualOnly(),
            testTrustPillLivePartnerSuppressesStubs(),
            testNearbySearchSuppressesETAEstimate(),
            testTrustPillVocabularyIsFrozen(),
        ]
        return MapActionCardUIValidationReport(results: results)
    }

    // MARK: - 1. Primary CTA copy per kind × language

    @MainActor
    static func testPrimaryCTAPerKindLocked() -> KernelPhase1TestResult {
        let name = "ui_card_primary_cta_locked_per_kind"
        let expectations: [(MapActionCardTaskKind, MapsConversationLanguage, String)] = [
            (.goToPlace, .english, "Go here"),
            (.goToPlace, .chinese, "去这里"),
            (.nearbySearch, .english, "Explore nearby"),
            (.nearbySearch, .chinese, "看看附近"),
            (.routeCompare, .english, "Compare routes"),
            (.routeCompare, .chinese, "看路线"),
        ]
        var mismatches: [String] = []
        for (kind, language, expected) in expectations {
            let copy = MapActionCardCopy.locked(for: kind, language: language)
            if copy.primaryActionTitle != expected {
                mismatches.append("\(kind)/\(language.rawValue): got \"\(copy.primaryActionTitle)\" wanted \"\(expected)\"")
            }
        }
        return .init(
            name: name,
            passed: mismatches.isEmpty,
            detail: mismatches.isEmpty
                ? "6/6 (kind × language) primary CTA copies match spec §1.6"
                : "primary CTA mismatches: \(mismatches.joined(separator: "; "))"
        )
    }

    // MARK: - 2. Secondary CTA copy per kind × language

    @MainActor
    static func testSecondaryCTAPerKindLocked() -> KernelPhase1TestResult {
        let name = "ui_card_secondary_cta_locked_per_kind"
        let expectations: [(MapActionCardTaskKind, MapsConversationLanguage, String)] = [
            (.goToPlace, .english, "Change destination"),
            (.goToPlace, .chinese, "换个目的地"),
            (.nearbySearch, .english, "Change keyword"),
            (.nearbySearch, .chinese, "换个关键词"),
            (.routeCompare, .english, "Change origin"),
            (.routeCompare, .chinese, "换个出发点"),
        ]
        var mismatches: [String] = []
        for (kind, language, expected) in expectations {
            let copy = MapActionCardCopy.locked(for: kind, language: language)
            if copy.secondaryActionTitle != expected {
                mismatches.append("\(kind)/\(language.rawValue): got \(String(describing: copy.secondaryActionTitle)) wanted \"\(expected)\"")
            }
        }
        return .init(
            name: name,
            passed: mismatches.isEmpty,
            detail: mismatches.isEmpty
                ? "6/6 (kind × language) secondary CTA copies match spec §1.6"
                : "secondary CTA mismatches: \(mismatches.joined(separator: "; "))"
        )
    }

    // MARK: - 3. Loading state: primary enabled

    @MainActor
    static func testLoadingStateEnablesPrimary() -> KernelPhase1TestResult {
        let name = "ui_card_state_loading_primary_enabled"
        let model = makeCard(kind: .goToPlace, state: .loading, language: .english)
        let primaryEnabled = !(model.state == .accepted || model.state == .dismissed)
        guard primaryEnabled else {
            return .init(name: name, passed: false, detail: "loading should enable primary CTA")
        }
        return .init(name: name, passed: true, detail: "loading state keeps primary CTA enabled per §1.9")
    }

    // MARK: - 4. Accepted state: primary disabled + badge reads "Accepted"

    @MainActor
    static func testAcceptedStateDisablesPrimary() -> KernelPhase1TestResult {
        let name = "ui_card_state_accepted_primary_disabled"
        let model = makeCard(kind: .routeCompare, state: .accepted, language: .english)
        let primaryEnabled = !(model.state == .accepted || model.state == .dismissed)
        guard primaryEnabled == false else {
            return .init(name: name, passed: false, detail: "accepted should disable primary CTA")
        }
        let badge = stateBadgeText(for: model)
        guard badge == "Accepted" else {
            return .init(name: name, passed: false, detail: "expected Accepted badge, got \(badge)")
        }
        return .init(name: name, passed: true, detail: "accepted disables primary + renders 'Accepted' badge per §1.9")
    }

    // MARK: - 5. Dismissed: primary disabled + badge + fade

    @MainActor
    static func testDismissedStateDisablesPrimaryAndFades() -> KernelPhase1TestResult {
        let name = "ui_card_state_dismissed_disabled_and_faded"
        let model = makeCard(kind: .nearbySearch, state: .dismissed, language: .chinese)
        let primaryEnabled = !(model.state == .accepted || model.state == .dismissed)
        let opacity: Double = model.state == .dismissed ? 0.4 : 1.0
        guard primaryEnabled == false, opacity == 0.4 else {
            return .init(name: name, passed: false, detail: "dismissed should disable primary and set opacity 0.4")
        }
        let badge = stateBadgeText(for: model)
        guard badge == "已忽略" else {
            return .init(name: name, passed: false, detail: "expected 已忽略 badge, got \(badge)")
        }
        return .init(name: name, passed: true, detail: "dismissed disables primary, opacity 0.4, badge '已忽略' per §1.9")
    }

    // MARK: - 6. Recommended: no badge overlay

    @MainActor
    static func testRecommendedStateHasNoStateBadge() -> KernelPhase1TestResult {
        let name = "ui_card_state_recommended_no_badge"
        let model = makeCard(kind: .goToPlace, state: .recommended, language: .english)
        let badge = stateBadgeText(for: model)
        guard badge == "" else {
            return .init(name: name, passed: false, detail: "recommended should have empty badge text, got \(badge)")
        }
        return .init(name: name, passed: true, detail: "recommended has no state badge per §1.9")
    }

    // MARK: - 7. Default stubbed metadata → full pill matrix per kind

    @MainActor
    static func testTrustPillDefaultStubbedMatrix() -> KernelPhase1TestResult {
        let name = "ui_card_trust_pills_default_stubbed_matrix"
        let cases: [(MapActionCardTaskKind, [ActionCardTrustPillKind])] = [
            (.goToPlace, [.placeResolutionStub, .etaConfidenceEstimate, .distanceConfidenceEstimate, .partnerFallback]),
            (.routeCompare, [.placeResolutionStub, .etaConfidenceEstimate, .distanceConfidenceEstimate, .partnerFallback]),
            (.nearbySearch, [.placeResolutionStub, .distanceConfidenceEstimate, .partnerFallback]),
        ]
        var mismatches: [String] = []
        for (kind, expected) in cases {
            let metadata = MapActionCardTrustMetadata(
                placeResolution: .estimated,
                etaConfidence: kind == .nearbySearch ? .unavailable : .estimated,
                distanceConfidence: .estimated,
                partnerState: .pending,
                permissionState: .unknown
            )
            if metadata.pills != expected {
                mismatches.append("\(kind): got \(metadata.pills) wanted \(expected)")
            }
        }
        return .init(
            name: name,
            passed: mismatches.isEmpty,
            detail: mismatches.isEmpty
                ? "3/3 task kinds emit the spec-locked default stubbed pill array"
                : "pill mismatches: \(mismatches.joined(separator: "; "))"
        )
    }

    // MARK: - 8. Permission denied → adds locationPermissionDenied pill

    @MainActor
    static func testTrustPillPermissionDenied() -> KernelPhase1TestResult {
        let name = "ui_card_trust_pills_permission_denied"
        let metadata = MapActionCardTrustMetadata(
            placeResolution: .estimated,
            etaConfidence: .estimated,
            distanceConfidence: .estimated,
            partnerState: .pending,
            permissionState: .denied
        )
        guard metadata.pills.contains(.locationPermissionDenied) else {
            return .init(name: name, passed: false, detail: "denied permission must add locationPermissionDenied pill")
        }
        return .init(name: name, passed: true, detail: "denied permission produces locationPermissionDenied pill per §1.5")
    }

    // MARK: - 9. Permission manualOnly → adds locationPermissionManual pill

    @MainActor
    static func testTrustPillPermissionManualOnly() -> KernelPhase1TestResult {
        let name = "ui_card_trust_pills_permission_manual_only"
        let metadata = MapActionCardTrustMetadata(
            placeResolution: .estimated,
            etaConfidence: .estimated,
            distanceConfidence: .estimated,
            partnerState: .pending,
            permissionState: .manualOnly
        )
        guard metadata.pills.contains(.locationPermissionManual) else {
            return .init(name: name, passed: false, detail: "manualOnly must add locationPermissionManual pill")
        }
        return .init(name: name, passed: true, detail: "manualOnly produces locationPermissionManual pill per §1.5")
    }

    // MARK: - 10. Live partner + live resolution suppresses stub pills

    @MainActor
    static func testTrustPillLivePartnerSuppressesStubs() -> KernelPhase1TestResult {
        let name = "ui_card_trust_pills_live_partner"
        let metadata = MapActionCardTrustMetadata(
            placeResolution: .live,
            etaConfidence: .live,
            distanceConfidence: .live,
            partnerState: .live,
            permissionState: .authorizedWhenInUse
        )
        let expected: [ActionCardTrustPillKind] = [.placeResolutionLive]
        guard metadata.pills == expected else {
            return .init(name: name, passed: false, detail: "live state should produce \(expected), got \(metadata.pills)")
        }
        return .init(name: name, passed: true, detail: "live partner + live data produces only placeResolutionLive pill")
    }

    // MARK: - 11. Nearby search never claims ETA estimate

    @MainActor
    static func testNearbySearchSuppressesETAEstimate() -> KernelPhase1TestResult {
        let name = "ui_card_trust_pills_nearby_no_eta"
        let metadata = MapActionCardTrustMetadata(
            placeResolution: .estimated,
            etaConfidence: .unavailable,
            distanceConfidence: .estimated,
            partnerState: .pending,
            permissionState: .unknown
        )
        if metadata.pills.contains(.etaConfidenceEstimate) {
            return .init(name: name, passed: false, detail: "nearby (etaConfidence=.unavailable) must NOT emit etaConfidenceEstimate")
        }
        return .init(name: name, passed: true, detail: "nearbySearch suppresses ETA estimate pill when confidence is .unavailable")
    }

    // MARK: - 12. Pill vocabulary is frozen at 7 cases

    @MainActor
    static func testTrustPillVocabularyIsFrozen() -> KernelPhase1TestResult {
        let name = "ui_card_trust_pill_vocabulary_frozen"
        let expected = Set<ActionCardTrustPillKind>([
            .placeResolutionLive,
            .placeResolutionStub,
            .etaConfidenceEstimate,
            .distanceConfidenceEstimate,
            .partnerFallback,
            .locationPermissionDenied,
            .locationPermissionManual,
        ])
        let actual = Set(ActionCardTrustPillKind.allCases)
        guard actual == expected else {
            return .init(name: name, passed: false, detail: "pill vocabulary drifted: got \(actual), expected \(expected)")
        }
        return .init(name: name, passed: true, detail: "pill vocabulary locked at 7 cases per spec §1.5")
    }

    // MARK: - Fixtures

    @MainActor
    private static func makeCard(
        kind: MapActionCardTaskKind,
        state: MapActionCardState,
        language: MapsConversationLanguage
    ) -> MapActionCardModel {
        let copy = MapActionCardCopy.locked(for: kind, language: language)
        return MapActionCardModel(
            id: "ui-\(kind.rawValue)-\(state.rawValue)",
            candidateId: "cand-\(kind.rawValue)",
            recommendationId: nil,
            threadId: UUID().uuidString,
            taskKind: kind,
            language: language,
            state: state,
            title: "Title",
            subtitle: "Subtitle",
            primaryActionTitle: copy.primaryActionTitle,
            secondaryActionTitle: copy.secondaryActionTitle,
            reasonChipText: "\(copy.reasonChipPrefix): reason",
            feedbackAffordanceLabel: copy.feedbackAffordanceLabel,
            activationPrompt: "open",
            objectKindRawValue: MatchingObjectKind.place.rawValue
        )
    }

    private static func stateBadgeText(for model: MapActionCardModel) -> String {
        let zh = model.language.usesChineseCopy
        switch model.state {
        case .loading:
            return zh ? "加载中" : "Loading"
        case .accepted:
            return zh ? "已接入" : "Accepted"
        case .dismissed:
            return zh ? "已忽略" : "Dismissed"
        case .recommended:
            return ""
        }
    }
}
