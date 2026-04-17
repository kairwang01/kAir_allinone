//
//  MapsRouteModels.swift
//  kAir
//
//  Local placeholder models for the v0.1 chat-to-route flow.
//

import Foundation

enum MapsConversationLanguage: String, Hashable {
    case chinese
    case english
}

enum MapsTravelMode: String, Hashable {
    case walking
    case driving

    var title: String {
        switch self {
        case .walking:
            return "Walking"
        case .driving:
            return "Driving"
        }
    }

    var chineseTitle: String {
        switch self {
        case .walking:
            return "步行"
        case .driving:
            return "驾车"
        }
    }

    var systemImage: String {
        switch self {
        case .walking:
            return "figure.walk"
        case .driving:
            return "car.fill"
        }
    }
}

struct PendingMapsIntent: Hashable {
    let destination: String
    let language: MapsConversationLanguage
    let originalPrompt: String
}

struct MapsRouteOption: Identifiable, Hashable {
    let id: String
    let badge: String
    let title: String
    let subtitle: String
    let eta: String
    let distance: String
    let emphasis: String
    let recommended: Bool
}

struct MapsRouteSession: Hashable {
    let destination: String
    let language: MapsConversationLanguage
    let mode: MapsTravelMode
    let generatedAt: Date
    let heroTitle: String
    let heroSummary: String
    let mapSummary: String
    let plannerTitle: String
    let plannerSummary: String
    let routeOptions: [MapsRouteOption]

    static func mock(
        destination: String,
        mode: MapsTravelMode,
        language: MapsConversationLanguage,
        generatedAt: Date = .now
    ) -> MapsRouteSession {
        switch (language, mode) {
        case (.chinese, .walking):
            return MapsRouteSession(
                destination: destination,
                language: language,
                mode: mode,
                generatedAt: generatedAt,
                heroTitle: "前往\(destination)的步行路线",
                heroSummary: "已按步行模式生成两条本地占位路线。后续这里会接真实 LLM 决策和地图服务。",
                mapSummary: "推荐线更安静，直达线更快。v0.1 先用文字结果承接到 Maps 页面。",
                plannerTitle: "本地模型窗口",
                plannerSummary: "这里预留给本地模型做地点解析、偏好判断、路线排序和解释输出。当前版本仍使用文字占位，不调用真实地图引擎。",
                routeOptions: [
                    MapsRouteOption(
                        id: "walking-calm",
                        badge: "推荐",
                        title: "安静街区步行线",
                        subtitle: "优先穿过更安静的住宅街区，路口更少，适合轻恢复式步行。",
                        eta: "14 分钟",
                        distance: "1.1 公里",
                        emphasis: "路口 1 个 · 噪声更低",
                        recommended: true
                    ),
                    MapsRouteOption(
                        id: "walking-fast",
                        badge: "更快",
                        title: "主路直达线",
                        subtitle: "时间更短，但人流更密、噪声更高，适合只追求效率时使用。",
                        eta: "11 分钟",
                        distance: "0.9 公里",
                        emphasis: "路口 3 个 · 更直接",
                        recommended: false
                    ),
                ]
            )

        case (.chinese, .driving):
            return MapsRouteSession(
                destination: destination,
                language: language,
                mode: mode,
                generatedAt: generatedAt,
                heroTitle: "前往\(destination)的驾车路线",
                heroSummary: "已按驾车模式生成两条本地占位路线。后续这里会接真实 LLM 决策和地图服务。",
                mapSummary: "主路线更稳妥，绕行线更安静。v0.1 先用文字结果承接到 Maps 页面。",
                plannerTitle: "本地模型窗口",
                plannerSummary: "这里预留给本地模型做地点解析、实时拥堵判断、用户偏好选择和路线解释。当前版本仍使用文字占位，不调用真实地图引擎。",
                routeOptions: [
                    MapsRouteOption(
                        id: "driving-steady",
                        badge: "推荐",
                        title: "主干道稳妥线",
                        subtitle: "转弯更少，导航解释更稳定，适合第一次去这个目的地时使用。",
                        eta: "9 分钟",
                        distance: "4.2 公里",
                        emphasis: "转弯 2 次 · 更稳",
                        recommended: true
                    ),
                    MapsRouteOption(
                        id: "driving-quiet",
                        badge: "更安静",
                        title: "低车流绕行线",
                        subtitle: "绕一点，但更避开高峰主路，适合想减少拥堵和停车压力时使用。",
                        eta: "11 分钟",
                        distance: "4.8 公里",
                        emphasis: "车流更低 · 停车更轻松",
                        recommended: false
                    ),
                ]
            )

        case (.english, .walking):
            return MapsRouteSession(
                destination: destination,
                language: language,
                mode: mode,
                generatedAt: generatedAt,
                heroTitle: "Walking routes to \(destination)",
                heroSummary: "Two local placeholder walking routes are ready. This surface will later connect to the real model and map runtime.",
                mapSummary: "The recommended route is calmer. The direct route is faster. v0.1 keeps the handoff textual on purpose.",
                plannerTitle: "Local model window",
                plannerSummary: "This area is reserved for on-device place resolution, preference ranking, and route explanation. v0.1 still uses text placeholders instead of real navigation output.",
                routeOptions: [
                    MapsRouteOption(
                        id: "walking-calm-en",
                        badge: "Recommended",
                        title: "Quiet residential walk",
                        subtitle: "A calmer path through side streets with fewer crossings and less noise.",
                        eta: "14 min",
                        distance: "1.1 km",
                        emphasis: "1 crossing · lower noise",
                        recommended: true
                    ),
                    MapsRouteOption(
                        id: "walking-fast-en",
                        badge: "Faster",
                        title: "Direct avenue route",
                        subtitle: "A shorter route that stays more direct, but it is busier and less calm.",
                        eta: "11 min",
                        distance: "0.9 km",
                        emphasis: "3 crossings · more direct",
                        recommended: false
                    ),
                ]
            )

        case (.english, .driving):
            return MapsRouteSession(
                destination: destination,
                language: language,
                mode: mode,
                generatedAt: generatedAt,
                heroTitle: "Driving routes to \(destination)",
                heroSummary: "Two local placeholder driving routes are ready. This surface will later connect to the real model and map runtime.",
                mapSummary: "The primary route is steadier. The detour is quieter. v0.1 keeps the handoff textual on purpose.",
                plannerTitle: "Local model window",
                plannerSummary: "This area is reserved for on-device destination parsing, traffic preference ranking, and route explanation. v0.1 still uses text placeholders instead of real navigation output.",
                routeOptions: [
                    MapsRouteOption(
                        id: "driving-steady-en",
                        badge: "Recommended",
                        title: "Primary steady drive",
                        subtitle: "Fewer turns and a cleaner explanation path for the first trip to this destination.",
                        eta: "9 min",
                        distance: "4.2 km",
                        emphasis: "2 turns · steadier",
                        recommended: true
                    ),
                    MapsRouteOption(
                        id: "driving-quiet-en",
                        badge: "Quieter",
                        title: "Low-traffic detour",
                        subtitle: "Slightly longer, but shaped for lighter traffic and easier parking decisions.",
                        eta: "11 min",
                        distance: "4.8 km",
                        emphasis: "lower traffic · easier parking",
                        recommended: false
                    ),
                ]
            )
        }
    }
}
