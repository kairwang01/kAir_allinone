//
//  SearchHomeView.swift
//  kAir
//
//  Search Execution Surface — read-only, contract-first preview surface.
//

import Foundation
import SwiftUI

struct SearchHomeView: View {
    let onReturnToChat: () -> Void
    private let projection: ProjectedProviderResult

    init(
        projection: ProjectedProviderResult = SearchHomeView.previewProjection,
        onReturnToChat: @escaping () -> Void = {}
    ) {
        self.projection = projection
        self.onReturnToChat = onReturnToChat
    }

    var body: some View {
        ExecutionSurfaceShell(
            inputs: shellInputs,
            onReturnToChat: onReturnToChat,
            primary: { primaryCard },
            supplementary: { supplementaryContent }
        )
        .navigationBarTitleDisplayMode(.inline)
    }

    private var shellInputs: ExecutionSurfaceShellInputs {
        ExecutionSurfaceShellInputs(
            navRail: ExecutionSurfaceNavRail(trustPills: [.partnerFallback]),
            title: ExecutionSurfaceTitle(
                eyebrow: "Search",
                title: "Search",
                summary: "Search is a read-only public information surface for cited life-service lookups."
            ),
            status: ExecutionSurfaceStatus(
                statusMessage: "Read-only contract — no crawler runtime, booking, order, or payment action"
            ),
            state: .ready,
            language: .english
        )
    }

    private var primaryCard: some View {
        ActionCardShell(
            object: primaryObject,
            state: .disabled
        )
    }

    private var primaryObject: MatchingObject {
        MatchingObject(
            id: "search-primary-\(projection.id)",
            kind: .searchResult,
            title: projection.summaryTitle,
            subtitleTokens: [
                projection.metadata.providerID ?? "No provider",
                projection.metadata.freshness.rawValue,
            ],
            reasonText: "Cited result prepared for review only.",
            primaryCTA: "Review result",
            secondaryCTA: nil
        )
    }

    private var supplementaryContent: some View {
        VStack(spacing: AppTheme.Metrics.sectionSpacing) {
            citedResultCard
            policyCard
            blockedActionsCard
        }
    }

    private var citedResultCard: some View {
        KAirSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cited result contract")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                if let hit = firstHit {
                    infoRow(title: "Source", value: hit.url)
                    infoRow(title: "Snippet", value: hit.snippet ?? "No snippet")
                } else {
                    infoRow(title: "Source", value: "No resolved result")
                }

                infoRow(
                    title: "Confidence",
                    value: String(format: "%.2f", projection.normalizedResult?.confidence ?? 0)
                )
            }
        }
    }

    private var policyCard: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Policy gates")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                policyRow("Provider", projection.metadata.providerID ?? "none")
                policyRow("Cost", projection.metadata.costClass.rawValue)
                policyRow("Freshness", projection.metadata.freshness.rawValue)
                policyRow("Privacy", projection.metadata.trace.privacyClass.rawValue)

                ForEach(projection.metadata.limitations, id: \.self) { limitation in
                    Label(limitation, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var blockedActionsCard: some View {
        KAirSurface(style: .sunken) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Disabled actions")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Text("This surface can prepare or display cited public information only. It cannot book, order, pay, write to merchants, or crawl inside the app.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var firstHit: WebHit? {
        guard case let .webSearch(hits) = projection.normalizedResult?.payload else {
            return nil
        }
        return hits.first
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func policyRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textMuted)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Palette.textPrimary)
        }
    }

    private static let previewDate = Date(timeIntervalSince1970: 1_800_000_000)

    private static var previewProjection: ProjectedProviderResult {
        let decision = SearchProviderPolicy.evaluate(
            SearchProviderRequest(
                traceID: "search-surface-preview",
                query: "late night ramen near me",
                capability: .localServiceSearch,
                privacyClass: .general,
                membershipTier: .plus,
                preferredProvider: .searchAPI,
                meteredProviderEntitlements: [.searchAPI],
                freshness: .livePreferred,
                resultDraft: SearchResultDraft(
                    sourceURL: URL(string: "https://example.com/ramen-hours")!,
                    title: "Late-night ramen hours",
                    snippet: "Public listing with hours, neighborhood context, and citation.",
                    attribution: "example.com",
                    confidence: 0.82,
                    limitations: ["Verify hours before visiting."]
                ),
                now: previewDate
            )
        )
        return ResultProjector.project(searchDecision: decision, createdAt: previewDate)
    }
}

#Preview("Search Surface") {
    NavigationStack {
        SearchHomeView()
    }
}
