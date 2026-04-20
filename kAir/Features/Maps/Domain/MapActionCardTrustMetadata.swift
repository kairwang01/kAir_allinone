//
//  MapActionCardTrustMetadata.swift
//  kAir
//
//  Sibling to the frozen `MapActionCardModel`. This is the **trust layer**:
//  it answers, for the user's benefit, "what in the card is real vs. what is
//  stubbed / degraded?" The 6-field / 4-state / 5-event card contract stays
//  untouched — trust is rendered as a separate list of pills in the card's
//  metadata row, per Maps UI Spec v1.
//
//  This type is pure view-model: no runtime / adapter / provider references.
//  Host code (ChatHomeView / AppBootstrap) composes it from the live
//  adapter `stubNote` + `MapsRuntime.permissionState`, then passes it to
//  `MapActionCardView`.
//

import Foundation

/// How confident we are that a given field reflects live data.
enum MapActionCardTrustConfidence: String, Codable, CaseIterable, Hashable, Sendable {
    /// Value comes from a live provider — safe to trust.
    case live
    /// Value comes from stubbed fixture data — presentable but not real.
    case estimated
    /// Value is not available at all — the card should render a degradation UI.
    case unavailable
}

/// Partner / source integration state. Mirrors what the adapter's `stubNote`
/// tells us without baking the string in.
enum MapActionCardTrustPartnerState: String, Codable, CaseIterable, Hashable, Sendable {
    /// Partner integration is wired and returned real data.
    case live
    /// Partner integration is not wired; we're rendering from a canned fixture.
    case pending
}

/// Frozen bundle of trust signals attached to a single `MapActionCardModel`.
/// Produce one per recommendation and pass it to `MapActionCardView.trustPills`.
struct MapActionCardTrustMetadata: Hashable, Sendable {
    let placeResolution: MapActionCardTrustConfidence
    let etaConfidence: MapActionCardTrustConfidence
    let distanceConfidence: MapActionCardTrustConfidence
    let partnerState: MapActionCardTrustPartnerState
    let permissionState: MapPermissionState

    init(
        placeResolution: MapActionCardTrustConfidence = .estimated,
        etaConfidence: MapActionCardTrustConfidence = .estimated,
        distanceConfidence: MapActionCardTrustConfidence = .estimated,
        partnerState: MapActionCardTrustPartnerState = .pending,
        permissionState: MapPermissionState = .unknown
    ) {
        self.placeResolution = placeResolution
        self.etaConfidence = etaConfidence
        self.distanceConfidence = distanceConfidence
        self.partnerState = partnerState
        self.permissionState = permissionState
    }

    /// Default "everything stubbed" metadata. This is the honest baseline
    /// while the partner layer is pending — users still see that the data is
    /// estimated rather than a polished, unreviewable surface.
    static let stubbedDefault = MapActionCardTrustMetadata(
        placeResolution: .estimated,
        etaConfidence: .estimated,
        distanceConfidence: .estimated,
        partnerState: .pending,
        permissionState: .unknown
    )

    /// Build from a `MapTaskAdapterResult` + the current `MapsRuntime`
    /// permission state. When the adapter is honest about being stubbed
    /// (`stubNote` non-empty and mentions "stubbed"), all three confidences
    /// default to `.estimated`.
    static func from(
        adapterResult: MapTaskAdapterResult,
        permissionState: MapPermissionState,
        taskKind: MapActionCardTaskKind
    ) -> MapActionCardTrustMetadata {
        let note = adapterResult.stubNote.lowercased()
        let looksStubbed = note.contains("stub") || adapterResult.task == nil
        let partner: MapActionCardTrustPartnerState = looksStubbed ? .pending : .live
        let place: MapActionCardTrustConfidence = looksStubbed ? .estimated : .live
        // ETA / distance only apply to route-compare and go-to; keep the
        // confidence meaningful for them and `.unavailable` for nearby.
        let etaBase: MapActionCardTrustConfidence = {
            switch taskKind {
            case .routeCompare, .goToPlace:
                return looksStubbed ? .estimated : .live
            case .nearbySearch:
                return .unavailable
            }
        }()
        let distanceBase: MapActionCardTrustConfidence = looksStubbed ? .estimated : .live

        return MapActionCardTrustMetadata(
            placeResolution: place,
            etaConfidence: etaBase,
            distanceConfidence: distanceBase,
            partnerState: partner,
            permissionState: permissionState
        )
    }

    /// The frozen vocabulary of trust pills that should render on the card's
    /// metadata row, in a stable order.
    ///
    /// Per Maps UI Spec v1 §1.5, this is the ONLY path to produce trust
    /// affordances on the card. Callers must not render free-form text.
    var pills: [ActionCardTrustPillKind] {
        var result: [ActionCardTrustPillKind] = []

        switch placeResolution {
        case .live:
            result.append(.placeResolutionLive)
        case .estimated:
            result.append(.placeResolutionStub)
        case .unavailable:
            break
        }

        switch etaConfidence {
        case .estimated:
            result.append(.etaConfidenceEstimate)
        case .live, .unavailable:
            break
        }

        switch distanceConfidence {
        case .estimated:
            result.append(.distanceConfidenceEstimate)
        case .live, .unavailable:
            break
        }

        if partnerState == .pending {
            result.append(.partnerFallback)
        }

        switch permissionState {
        case .denied:
            result.append(.locationPermissionDenied)
        case .manualOnly:
            result.append(.locationPermissionManual)
        case .authorizedWhenInUse, .notDetermined, .unknown:
            break
        }

        return result
    }
}
