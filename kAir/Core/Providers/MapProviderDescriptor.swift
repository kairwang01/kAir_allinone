//
//  MapProviderDescriptor.swift
//  kAir
//
//  Pure provider descriptors for Apple/Gaode/Google/cache map routing.
//  Descriptors do not call SDKs or web APIs directly.
//

import Foundation

/// Describes one provider's routing/cost/coverage characteristics. The same
/// shape can later describe search or partner providers, but A5b seeds the
/// map-oriented registry first.
struct MapProviderDescriptor: Codable, Hashable, Sendable, Identifiable {
    let providerID: String
    let displayName: String
    let family: ProviderFamily
    let supportedRegions: Set<ProviderRegion>
    let supportedCapabilities: Set<ProviderCapability>
    let minimumMembership: MembershipTier
    let costClass: ProviderCostClass
    let attributionRequired: Bool
    let supportsNativeSDK: Bool
    let supportsWebService: Bool
    let supportsExternalHandoff: Bool
    let cachePolicy: CachePolicy
    let priority: Int

    var id: String { providerID }

    func supports(capability: ProviderCapability) -> Bool {
        supportedCapabilities.contains(capability)
    }

    func supports(region: ProviderRegion) -> Bool {
        supportedRegions.contains(.global) || supportedRegions.contains(region)
    }

    /// Cache/freshness contract for a provider result.
    enum CachePolicy: String, Codable, Hashable, Sendable, CaseIterable {
        case noCache
        case shortLived
        case userSavedOnly
        case staleAllowedWithBadge
    }
}

extension MapProviderDescriptor {
    /// Fixture registry for A5b. No real SDK, key, endpoint, or quota is wired.
    static let defaultRegistry: [MapProviderDescriptor] = [
        MapProviderDescriptor(
            providerID: "apple-local",
            displayName: "Apple Local",
            family: .appleLocal,
            supportedRegions: [.global],
            supportedCapabilities: [.mapDisplay, .placeSearch, .routePlanning],
            minimumMembership: .free,
            costClass: .freeLocal,
            attributionRequired: false,
            supportsNativeSDK: true,
            supportsWebService: false,
            supportsExternalHandoff: true,
            cachePolicy: .shortLived,
            priority: 10
        ),
        MapProviderDescriptor(
            providerID: "gaode",
            displayName: "Gaode",
            family: .gaode,
            supportedRegions: [.china],
            supportedCapabilities: [.placeSearch, .routePlanning, .localServiceSearch],
            minimumMembership: .plus,
            costClass: .includedQuota,
            attributionRequired: true,
            supportsNativeSDK: true,
            supportsWebService: true,
            supportsExternalHandoff: true,
            cachePolicy: .shortLived,
            priority: 20
        ),
        MapProviderDescriptor(
            providerID: "google-maps",
            displayName: "Google Maps",
            family: .googleMaps,
            supportedRegions: [.global],
            supportedCapabilities: [.placeSearch, .routePlanning, .localServiceSearch],
            minimumMembership: .plus,
            costClass: .meteredPremium,
            attributionRequired: true,
            supportsNativeSDK: true,
            supportsWebService: true,
            supportsExternalHandoff: true,
            cachePolicy: .shortLived,
            priority: 30
        ),
        MapProviderDescriptor(
            providerID: "local-cache",
            displayName: "Local Cache",
            family: .cache,
            supportedRegions: [.global],
            supportedCapabilities: [.mapDisplay, .placeSearch, .routePlanning, .localServiceSearch],
            minimumMembership: .free,
            costClass: .freeLocal,
            attributionRequired: false,
            supportsNativeSDK: false,
            supportsWebService: false,
            supportsExternalHandoff: false,
            cachePolicy: .staleAllowedWithBadge,
            priority: 100
        ),
    ]
}
