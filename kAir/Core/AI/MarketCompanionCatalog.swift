//
//  MarketCompanionCatalog.swift
//  kAir
//
//  Value-only product direction catalog for the overseas companion lanes.
//

import Foundation

enum MarketCompanionDirectionID: String, CaseIterable, Sendable {
    case celebrityFanCompanion
    case gamingCompanion
    case intelligenceMonitor
    case knowledgeManager
    case officeHelper
    case pcButler
    case growthAccelerator
    case lifestyleArtist
}

enum MarketCompanionBoundary: String, CaseIterable, Sendable {
    case readOnlyMonitoring
    case userProvidedContentOnly
    case userConfirmedExternalHandoff
    case noHiddenThirdPartyAutomation
    case noPurchasePostOrSystemChangeWithoutConfirmation
    case noCopyrightOrTermsBypass
}

struct MarketCompanionDirection: Hashable, Identifiable, Sendable {
    let id: MarketCompanionDirectionID
    let localizedTitle: String
    let headline: String
    let summary: String
    let exampleActions: [String]
    let capabilities: [CapabilityKind]
    let overseasProviderExamples: [String]
    let boundaries: Set<MarketCompanionBoundary>

    var surfaces: [SurfaceKind] {
        var seen = Set<SurfaceKind>()
        return capabilities.compactMap { capability in
            let surface = capability.surfaceFamily
            guard seen.insert(surface).inserted else { return nil }
            return surface
        }
    }

    var isOverseasFirst: Bool {
        overseasProviderExamples.isEmpty == false
    }
}

enum MarketCompanionCatalog {
    static let directions: [MarketCompanionDirection] =
        MarketCompanionDirectionID.allCases.map { direction($0) }

    static func direction(_ id: MarketCompanionDirectionID) -> MarketCompanionDirection {
        switch id {
        case .celebrityFanCompanion:
            return MarketCompanionDirection(
                id: id,
                localizedTitle: "追星好搭子",
                headline: "Celebrity fan companion",
                summary: "Celebrity news search, fan check-in preparation, and HD media organization for overseas fan workflows.",
                exampleActions: [
                    "Track public celebrity news and release schedules.",
                    "Prepare fan check-in reminders and external handoff copy.",
                    "Organize user-provided photos, clips, and links into local collections.",
                ],
                capabilities: [.webSearch, .aiCompletion, .localStoreLookup],
                overseasProviderExamples: ["Google News", "X", "Instagram", "TikTok", "YouTube", "Reddit"],
                boundaries: commonBoundaries.union([.readOnlyMonitoring, .userConfirmedExternalHandoff])
            )

        case .gamingCompanion:
            return MarketCompanionDirection(
                id: id,
                localizedTitle: "游戏陪你玩",
                headline: "Gaming companion",
                summary: "Limited-time benefit monitoring, strategy planning, and daily quest preparation without game-bot automation.",
                exampleActions: [
                    "Monitor public event windows and patch notes.",
                    "Plan the next efficient in-game actions from user-provided progress.",
                    "Prepare daily quest checklists for user-confirmed play.",
                ],
                capabilities: [.webSearch, .aiCompletion, .localStoreLookup],
                overseasProviderExamples: ["Steam", "PlayStation", "Xbox", "Discord", "Twitch", "Reddit"],
                boundaries: commonBoundaries.union([.readOnlyMonitoring, .userConfirmedExternalHandoff])
            )

        case .intelligenceMonitor:
            return MarketCompanionDirection(
                id: id,
                localizedTitle: "情报监控器",
                headline: "Intelligence monitor",
                summary: "Industry news, social news, and ticket information collection with source-aware monitoring.",
                exampleActions: [
                    "Monitor major tech-company news and public market signals.",
                    "Summarize social news from cited sources.",
                    "Collect ticket availability signals before a user-confirmed purchase handoff.",
                ],
                capabilities: [.webSearch, .aiCompletion, .localStoreLookup],
                overseasProviderExamples: ["Google News", "Hacker News", "X", "Ticketmaster", "SeatGeek", "Eventbrite"],
                boundaries: commonBoundaries.union([.readOnlyMonitoring, .userConfirmedExternalHandoff])
            )

        case .knowledgeManager:
            return MarketCompanionDirection(
                id: id,
                localizedTitle: "知识管理员",
                headline: "Knowledge manager",
                summary: "Book distillation, personal note refinement, and job-preparation material organization.",
                exampleActions: [
                    "Distill user-provided book notes or permitted excerpts.",
                    "Refine personal notes into reusable study cards.",
                    "Prepare resumes, interview outlines, and job research packs.",
                ],
                capabilities: [.aiCompletion, .threadLookup, .localStoreLookup, .webSearch],
                overseasProviderExamples: ["Kindle", "Apple Books", "Google Drive", "Notion", "LinkedIn", "Indeed"],
                boundaries: commonBoundaries.union([.userProvidedContentOnly, .readOnlyMonitoring])
            )

        case .officeHelper:
            return MarketCompanionDirection(
                id: id,
                localizedTitle: "打工好帮手",
                headline: "Office helper",
                summary: "File conversion, contract information review, and operations data analysis with explicit user review.",
                exampleActions: [
                    "Prepare file conversion plans and local export previews.",
                    "Extract contract fields and flag review points without legal-advice claims.",
                    "Summarize spreadsheet or operations data from user-provided files.",
                ],
                capabilities: [.aiCompletion, .localStoreLookup, .webSearch],
                overseasProviderExamples: ["Google Drive", "Microsoft 365", "Dropbox", "Adobe Acrobat", "DocuSign", "Slack"],
                boundaries: commonBoundaries.union([.userProvidedContentOnly, .userConfirmedExternalHandoff])
            )

        case .pcButler:
            return MarketCompanionDirection(
                id: id,
                localizedTitle: "电脑小管家",
                headline: "PC butler",
                summary: "System-setting guidance, cleanup planning, and network-repair triage through public, user-confirmed paths.",
                exampleActions: [
                    "Explain how to change a system setting in plain language.",
                    "Prepare cleanup checklists and safe delete previews.",
                    "Triage network issues before opening system settings or diagnostics.",
                ],
                capabilities: [.aiCompletion, .localStoreLookup, .webSearch],
                overseasProviderExamples: ["Apple Shortcuts", "macOS System Settings", "Windows Settings", "Speedtest", "Cloudflare WARP"],
                boundaries: commonBoundaries.union([.readOnlyMonitoring, .userConfirmedExternalHandoff])
            )

        case .growthAccelerator:
            return MarketCompanionDirection(
                id: id,
                localizedTitle: "成长加速器",
                headline: "Growth accelerator",
                summary: "English-learning reading support, literature organization, and AI-tool guidance.",
                exampleActions: [
                    "Act as an English reading companion with vocabulary and rewrite support.",
                    "Organize papers, citations, and research notes.",
                    "Recommend AI tools and explain safe usage steps.",
                ],
                capabilities: [.aiCompletion, .webSearch, .localStoreLookup],
                overseasProviderExamples: ["Duolingo", "YouTube", "arXiv", "Semantic Scholar", "Google Scholar", "OpenAI Docs"],
                boundaries: commonBoundaries.union([.userProvidedContentOnly, .readOnlyMonitoring])
            )

        case .lifestyleArtist:
            return MarketCompanionDirection(
                id: id,
                localizedTitle: "生活艺术家",
                headline: "Lifestyle artist",
                summary: "Movie picks, baby-album organization, and travel-plan evaluation with honest availability and booking handoff.",
                exampleActions: [
                    "Recommend high-rated movies from cited sources and user taste.",
                    "Organize user-provided baby photos into album plans.",
                    "Evaluate travel routes, lodging tradeoffs, and booking readiness.",
                ],
                capabilities: [.videoPlayback, .aiCompletion, .placeSearch, .routePlanning, .webSearch],
                overseasProviderExamples: ["Letterboxd", "IMDb", "Rotten Tomatoes", "Apple Photos", "Google Maps", "Tripadvisor", "Booking.com"],
                boundaries: commonBoundaries.union([.userProvidedContentOnly, .readOnlyMonitoring, .userConfirmedExternalHandoff])
            )
        }
    }

    private static let commonBoundaries: Set<MarketCompanionBoundary> = [
        .noHiddenThirdPartyAutomation,
        .noPurchasePostOrSystemChangeWithoutConfirmation,
        .noCopyrightOrTermsBypass,
    ]
}
