//
//  MapsIntentRouter.swift
//  kAir
//
//  Chat-facing map intent router. It only emits chat answers, confirm cards, or open-maps handoffs.
//

import Foundation

enum MapsIntentRouterDecision {
    case chatAnswer
    case confirmCard
    case openMaps
}

struct MapsIntentRouterResponse {
    let decision: MapsIntentRouterDecision
    let message: ConversationMessage
    let pendingTask: MapTask?
    let openTask: MapTask?
}

enum MapsIntentRouter {
    static func handlePrompt(
        _ prompt: String,
        threadId: UUID,
        pendingTask: MapTask?,
        runtime: MapsRuntime
    ) async -> MapsIntentRouterResponse? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        if let pendingTask, pendingTask.needsManualInput {
            return await handleManualInput(trimmed, task: pendingTask, runtime: runtime)
        }

        guard let intent = ParsedMapsIntent.parse(trimmed) else {
            return nil
        }

        switch intent {
        case .goTo(let query, let language):
            let candidates = await runtime.resolvePlaces(matching: query)
            guard candidates.isEmpty == false else {
                return noResultsResponse(
                    language: language,
                    query: query,
                    title: language.usesChineseCopy ? "没找到这个地点" : "That place could not be found"
                )
            }

            if candidates.count == 1, let candidate = candidates.first {
                let task = MapTask(
                    threadId: threadId,
                    taskType: .goToPlace,
                    query: query,
                    destinationCandidates: candidates,
                    selectedDestination: candidate,
                    permissionState: runtime.permissionState,
                    entryMode: .directOpenMaps,
                    resultSummary: language.usesChineseCopy
                        ? "已确认目的地：\(candidate.title)。"
                        : "Confirmed destination: \(candidate.title).",
                    language: language,
                    statusMessage: language.usesChineseCopy
                        ? "AI 已锁定目的地，正在打开实时地图。"
                        : "AI locked the destination and is opening the live map."
                )
                return openMapsResponse(task: task)
            }

            let task = MapTask(
                threadId: threadId,
                taskType: .goToPlace,
                query: query,
                destinationCandidates: candidates,
                permissionState: runtime.permissionState,
                entryMode: .confirmCard,
                resultSummary: language.usesChineseCopy
                    ? "目的地仍需确认。"
                    : "The destination still needs confirmation.",
                language: language
            )
            return ambiguityResponse(task: task)

        case .nearby(let query, let language):
            if runtime.permissionState.canUseCurrentLocation {
                let task = MapTask(
                    threadId: threadId,
                    taskType: .nearbySearch,
                    query: query,
                    origin: MapPlaceCandidate.currentLocationPlaceholder(language: language),
                    permissionState: runtime.permissionState,
                    entryMode: .directOpenMaps,
                    resultSummary: language.usesChineseCopy
                        ? "已准备查看附近 \(query) 结果。"
                        : "Prepared the nearby \(query) search.",
                    language: language,
                    statusMessage: language.usesChineseCopy
                        ? "将使用当前位置进入 Maps。"
                        : "Maps will open around your current location."
                )
                return openMapsResponse(task: task)
            }

            let task = MapTask(
                threadId: threadId,
                taskType: .nearbySearch,
                query: query,
                permissionState: runtime.permissionState == .denied ? .manualOnly : runtime.permissionState,
                entryMode: .confirmCard,
                resultSummary: language.usesChineseCopy
                    ? "附近搜索仍在等待区域。"
                    : "Nearby search is waiting for an area.",
                language: language
            )
            return confirmLocationResponse(task: task)

        case .recommendation(let query, let language):
            let candidates = await runtime.recommendationCandidates(for: query, language: language)
            guard candidates.isEmpty == false else {
                return noResultsResponse(
                    language: language,
                    query: query,
                    title: language.usesChineseCopy ? "没有推荐结果" : "No recommendations yet"
                )
            }

            let task = MapTask(
                threadId: threadId,
                taskType: .recommendation,
                query: query,
                permissionState: runtime.permissionState,
                entryMode: .chatAnswer,
                resultSummary: language.usesChineseCopy
                    ? "已准备推荐地点的地图分布。"
                    : "Prepared the recommendation map view.",
                language: language,
                nearbyResults: candidates,
                requestedDisplayMode: .list
            )
            return recommendationResponse(task: task)

        case .route(let destinationQuery, let originQuery, let language):
            let candidates = await runtime.resolvePlaces(matching: destinationQuery)
            guard candidates.isEmpty == false else {
                return noResultsResponse(
                    language: language,
                    query: destinationQuery,
                    title: language.usesChineseCopy ? "目的地没找到" : "Destination not found"
                )
            }

            let origin = await resolvedOrigin(
                from: originQuery,
                language: language,
                runtime: runtime
            )

            if candidates.count == 1, let destination = candidates.first {
                var task = MapTask(
                    threadId: threadId,
                    taskType: .routeComparison,
                    query: destinationQuery,
                    origin: origin ?? (runtime.permissionState.canUseCurrentLocation
                        ? MapPlaceCandidate.currentLocationPlaceholder(language: language)
                        : nil),
                    destinationCandidates: candidates,
                    selectedDestination: destination,
                    transportMode: .driving,
                    permissionState: runtime.permissionState,
                    entryMode: .confirmCard,
                    resultSummary: language.usesChineseCopy
                        ? "已准备路线比较。"
                        : "Prepared the route comparison.",
                    language: language
                )

                if task.origin != nil {
                    task.entryMode = .directOpenMaps
                    return openMapsResponse(task: task)
                }

                return confirmLocationResponse(task: task)
            }

            let task = MapTask(
                threadId: threadId,
                taskType: .routeComparison,
                query: destinationQuery,
                origin: origin,
                destinationCandidates: candidates,
                transportMode: .driving,
                permissionState: runtime.permissionState,
                entryMode: .confirmCard,
                resultSummary: language.usesChineseCopy
                    ? "路线比较仍需先确认目的地。"
                    : "Route comparison still needs a destination confirmation.",
                language: language
            )
            return ambiguityResponse(task: task)
        }
    }

    static func handleAction(
        _ action: ConversationToolAction,
        pendingTask: MapTask?,
        runtime: MapsRuntime
    ) async -> MapsIntentRouterResponse? {
        guard var task = pendingTask else {
            return nil
        }

        switch action.kind {
        case .selectMapDestination:
            guard
                let payload = action.payload,
                let candidate = task.destinationCandidates.first(where: { $0.id == payload })
            else {
                return nil
            }

            task.selectedDestination = candidate

            if task.taskType == .routeComparison {
                if task.origin == nil, runtime.permissionState.canUseCurrentLocation {
                    task.origin = MapPlaceCandidate.currentLocationPlaceholder(language: task.language)
                }

                if task.origin != nil {
                    return openMapsResponse(task: task)
                }

                return confirmLocationResponse(task: task)
            }

            return confirmDestinationResponse(task: task)

        case .openMaps:
            if task.taskType == .routeComparison, task.origin == nil {
                return confirmLocationResponse(task: task)
            }

            if task.taskType == .goToPlace,
               task.origin == nil,
               runtime.permissionState.canUseCurrentLocation
            {
                task.origin = MapPlaceCandidate.currentLocationPlaceholder(language: task.language)
            }

            task.entryMode = .actionOpenMaps
            return openMapsResponse(task: task)

        case .useCurrentLocation:
            if let anchor = await runtime.requestCurrentLocationAnchor(language: task.language) {
                task.permissionState = runtime.permissionState
                task.origin = anchor
                task.entryMode = .actionOpenMaps
                return openMapsResponse(task: task)
            }

            task.permissionState = runtime.permissionState == .denied ? .manualOnly : runtime.permissionState
            task.manualInputKind = manualInputKind(for: task)
            return confirmLocationResponse(task: task)

        case .enterManualLocation:
            task.manualInputKind = manualInputKind(for: task)
            return manualPromptResponse(task: task)

        case .showRecommendationMap:
            task.entryMode = .actionOpenMaps
            task.requestedDisplayMode = .map
            return openMapsResponse(task: task)
        }
    }

    private static func handleManualInput(
        _ prompt: String,
        task: MapTask,
        runtime: MapsRuntime
    ) async -> MapsIntentRouterResponse {
        guard let anchor = await runtime.resolveManualLocation(query: prompt, language: task.language) else {
            return noResultsResponse(
                language: task.language,
                query: prompt,
                title: task.language.usesChineseCopy ? "没找到这个地点" : "That place could not be found"
            ) ?? manualPromptResponse(task: task)
        }

        var task = task
        task.manualInputKind = nil

        switch task.manualInputKind ?? manualInputKind(for: task) {
        case .anchor:
            task.origin = anchor
            task.entryMode = .actionOpenMaps
            return openMapsResponse(task: task)
        case .origin:
            task.origin = anchor
            task.entryMode = .actionOpenMaps
            return openMapsResponse(task: task)
        case .destination:
            task.selectedDestination = anchor
            task.destinationCandidates = [anchor]
            return confirmDestinationResponse(task: task)
        }
    }

    private static func confirmDestinationResponse(task: MapTask) -> MapsIntentRouterResponse {
        let language = task.language
        let destination = task.selectedDestination ?? task.destinationCandidates.first
        let summary = destination.map {
            language.usesChineseCopy
                ? "已锁定目的地“\($0.title)”。先看一下地点，再决定是否打开 Maps。"
                : "The destination “\($0.title)” is locked. Review it here, then decide whether to open Maps."
        } ?? (language.usesChineseCopy
            ? "先确认这个地点，再打开 Maps。"
            : "Confirm this place before opening Maps.")

        let result = ConversationToolResult(
            id: "maps-confirm-destination",
            title: language.usesChineseCopy ? "确认目的地" : "Confirm destination",
            summary: summary,
            state: .ready,
            metrics: [
                .init(key: language.usesChineseCopy ? "任务" : "Task", value: task.taskType.title(for: language)),
                .init(key: language.usesChineseCopy ? "地点" : "Place", value: destination?.title ?? task.query),
                .init(key: language.usesChineseCopy ? "下一步" : "Next", value: language.usesChineseCopy ? "查看路线" : "View route")
            ],
            footer: language.usesChineseCopy
                ? "V1 固定先确认一次，避免误跳转。"
                : "V1 always confirms once first to reduce accidental map handoffs.",
            actions: [
                ConversationToolAction(
                    title: language.usesChineseCopy ? "查看路线" : "View route",
                    systemImage: "map",
                    kind: .openMaps,
                    style: .primary
                )
            ]
        )

        let text = language.usesChineseCopy
            ? "我先把目的地确认卡片放在这里。你点“查看路线”后再进入 Maps。"
            : "I left the destination confirmation card here first. Open Maps only after you tap “View route.”"

        return MapsIntentRouterResponse(
            decision: .confirmCard,
            message: .assistant(
                text: text,
                tags: ["Maps", language.usesChineseCopy ? "确认目的地" : "Destination confirmed"],
                toolResults: [result]
            ),
            pendingTask: task,
            openTask: nil
        )
    }

    private static func ambiguityResponse(task: MapTask) -> MapsIntentRouterResponse {
        let language = task.language
        let actions = Array(task.destinationCandidates.prefix(3)).map { candidate in
            ConversationToolAction(
                title: candidate.title,
                systemImage: "mappin.and.ellipse",
                kind: .selectMapDestination,
                payload: candidate.id,
                style: .secondary
            )
        }

        let result = ConversationToolResult(
            id: "maps-ambiguity",
            title: language.usesChineseCopy ? "地点需要确认" : "Place needs confirmation",
            summary: language.usesChineseCopy
                ? "“\(task.query)” 对应多个候选地点。先在聊天里选一个，再进入 Maps。"
                : "“\(task.query)” maps to multiple candidates. Choose one in chat before opening Maps.",
            state: .working,
            metrics: [
                .init(key: language.usesChineseCopy ? "候选" : "Candidates", value: "\(task.destinationCandidates.count)"),
                .init(key: language.usesChineseCopy ? "任务" : "Task", value: task.taskType.title(for: language)),
                .init(key: language.usesChineseCopy ? "出口" : "Surface", value: "Maps")
            ],
            footer: language.usesChineseCopy
                ? "歧义地点不能直接跳图。"
                : "Ambiguous places do not open Maps directly.",
            actions: actions
        )

        let text = language.usesChineseCopy
            ? "这个地点有歧义，我先把候选项列出来。你选一个后我再继续。"
            : "This place is ambiguous, so I listed the candidates first. Pick one and I’ll continue."

        return MapsIntentRouterResponse(
            decision: .confirmCard,
            message: .assistant(
                text: text,
                tags: ["Maps", language.usesChineseCopy ? "歧义地点" : "Ambiguous place"],
                toolResults: [result]
            ),
            pendingTask: task,
            openTask: nil
        )
    }

    private static func confirmLocationResponse(task: MapTask) -> MapsIntentRouterResponse {
        let language = task.language
        let manualKind = manualInputKind(for: task)
        let isRouteTask = task.taskType == .routeComparison

        let result = ConversationToolResult(
            id: "maps-location-confirm",
            title: language.usesChineseCopy ? "先确认位置来源" : "Confirm the location source first",
            summary: language.usesChineseCopy
                ? (isRouteTask
                    ? "还缺起点。你可以用当前位置，也可以手动输入地点。"
                    : "还缺搜索区域。你可以用当前位置，也可以手动输入地点。")
                : (isRouteTask
                    ? "An origin is still missing. Use your current location or enter a place manually."
                    : "A search area is still missing. Use your current location or enter a place manually."),
            state: .working,
            metrics: [
                .init(key: language.usesChineseCopy ? "权限" : "Permission", value: permissionLabel(task.permissionState, language: language)),
                .init(key: language.usesChineseCopy ? "任务" : "Task", value: task.taskType.title(for: language)),
                .init(key: language.usesChineseCopy ? "回退" : "Fallback", value: language.usesChineseCopy ? "手动输入地点" : "Manual place input")
            ],
            footer: language.usesChineseCopy
                ? "只申请前台定位；拒绝后仍可继续。"
                : "Only while-in-use location is requested. Manual entry still works after denial.",
            actions: [
                ConversationToolAction(
                    title: language.usesChineseCopy ? "使用当前位置" : "Use current location",
                    systemImage: "location",
                    kind: .useCurrentLocation,
                    style: .primary
                ),
                ConversationToolAction(
                    title: language.usesChineseCopy ? "手动输入地点" : "Enter a place manually",
                    systemImage: "keyboard",
                    kind: .enterManualLocation,
                    payload: manualKind.rawValue,
                    style: .secondary
                )
            ]
        )

        let text = language.usesChineseCopy
            ? "我还不直接跳转 Maps。先把当前位置和手动输入两条路都给你。"
            : "I’m not jumping into Maps yet. First I’m giving you both paths: current location or manual input."

        return MapsIntentRouterResponse(
            decision: .confirmCard,
            message: .assistant(
                text: text,
                tags: ["Maps", language.usesChineseCopy ? "位置确认" : "Location confirmation"],
                toolResults: [result]
            ),
            pendingTask: task,
            openTask: nil
        )
    }

    private static func manualPromptResponse(task: MapTask) -> MapsIntentRouterResponse {
        let language = task.language
        let inputKind = manualInputKind(for: task)

        let result = ConversationToolResult(
            id: "maps-manual-input",
            title: language.usesChineseCopy ? "等待手动地点" : "Waiting for a manual place",
            summary: inputKind.prompt(for: language),
            state: .working,
            metrics: [
                .init(key: language.usesChineseCopy ? "方式" : "Mode", value: language.usesChineseCopy ? "手动输入" : "Manual input"),
                .init(key: language.usesChineseCopy ? "任务" : "Task", value: task.taskType.title(for: language)),
                .init(key: language.usesChineseCopy ? "下一步" : "Next", value: language.usesChineseCopy ? "直接回复地点名" : "Reply with a place name")
            ],
            footer: language.usesChineseCopy
                ? "不会请求后台定位，也不会记录连续轨迹。"
                : "No background location is requested and no continuous movement history is stored.",
            actions: []
        )

        let text = language.usesChineseCopy
            ? inputKind.prompt(for: language)
            : inputKind.prompt(for: language)

        var task = task
        task.manualInputKind = inputKind

        return MapsIntentRouterResponse(
            decision: .confirmCard,
            message: .assistant(
                text: text,
                tags: ["Maps", language.usesChineseCopy ? "手动地点" : "Manual place"],
                toolResults: [result]
            ),
            pendingTask: task,
            openTask: nil
        )
    }

    private static func recommendationResponse(task: MapTask) -> MapsIntentRouterResponse {
        let language = task.language
        let candidates = Array(task.nearbyResults.prefix(3))
        let numberedSummary = candidates.enumerated()
            .map { index, candidate in
                let reason = candidate.reason ?? candidate.subtitle
                return "\(index + 1). \(candidate.title) — \(reason)"
            }
            .joined(separator: "\n")

        let result = ConversationToolResult(
            id: "maps-recommendation",
            title: language.usesChineseCopy ? "先在聊天里给你推荐" : "Recommendations first, in chat",
            summary: language.usesChineseCopy
                ? "我先给 2 到 5 个高相关候选。只有在你要看地图分布时才进入 Maps。"
                : "I’m keeping this lightweight with a few strong candidates. Maps opens only if you want the spatial view.",
            state: .ready,
            metrics: [
                .init(key: language.usesChineseCopy ? "候选" : "Candidates", value: "\(task.nearbyResults.count)"),
                .init(key: language.usesChineseCopy ? "比较" : "Compare", value: language.usesChineseCopy ? "聊天内先看理由" : "Reasoning first in chat"),
                .init(key: language.usesChineseCopy ? "地图" : "Maps", value: language.usesChineseCopy ? "按需再开" : "Open only if needed")
            ],
            footer: numberedSummary,
            actions: [
                ConversationToolAction(
                    title: language.usesChineseCopy ? "看地图分布" : "See map distribution",
                    systemImage: "map",
                    kind: .showRecommendationMap,
                    style: .secondary
                )
            ]
        )

        let intro = language.usesChineseCopy
            ? "先给你几家高相关候选："
            : "Here are a few strong candidates first:"

        return MapsIntentRouterResponse(
            decision: .chatAnswer,
            message: .assistant(
                text: "\(intro)\n\(numberedSummary)",
                tags: ["Maps", language.usesChineseCopy ? "推荐" : "Recommendations"],
                toolResults: [result]
            ),
            pendingTask: task,
            openTask: nil
        )
    }

    private static func openMapsResponse(task: MapTask) -> MapsIntentRouterResponse {
        let language = task.language
        let destination = task.selectedDestination?.title ?? task.query
        let title = language.usesChineseCopy ? "已交给 Maps" : "Handed off to Maps"
        let summary: String

        switch task.taskType {
        case .goToPlace:
            summary = language.usesChineseCopy
                ? "会在实时地图里继续完成“去 \(destination)”的搜索与导航。"
                : "The live map will continue the search and navigation flow for “\(destination)”."
        case .nearbySearch:
            summary = language.usesChineseCopy
                ? "会在 Maps 里继续展示附近 \(task.query) 结果。"
                : "Maps will continue the nearby \(task.query) search."
        case .recommendation:
            summary = language.usesChineseCopy
                ? "会在 Maps 里比较这些推荐地点的空间分布。"
                : "Maps will compare the spatial spread of these recommendations."
        case .routeComparison:
            summary = language.usesChineseCopy
                ? "会在 Maps 里比较步行、驾车和公交。"
                : "Maps will compare walking, driving, and transit."
        }

        let result = ConversationToolResult(
            id: "maps-open",
            title: title,
            summary: summary,
            state: .ready,
            metrics: [
                .init(key: language.usesChineseCopy ? "任务" : "Task", value: task.taskType.title(for: language)),
                .init(key: language.usesChineseCopy ? "线程" : "Thread", value: language.usesChineseCopy ? "保持同一会话" : "Same conversation"),
                .init(key: language.usesChineseCopy ? "返回" : "Return", value: language.usesChineseCopy ? "强制回聊天" : "Back to chat")
            ],
            footer: language.usesChineseCopy
                ? "Maps 只是二级任务页，不会变成独立首页。"
                : "Maps stays a focused task page and not a separate home.",
            actions: []
        )

        let text = language.usesChineseCopy
            ? "进入 Maps 继续这个任务。原线程会保留，返回后回写摘要。"
            : "Entering Maps to continue this task. The original thread stays here and receives the return summary."

        return MapsIntentRouterResponse(
            decision: .openMaps,
            message: .system(
                text: text,
                toolResults: [result]
            ),
            pendingTask: nil,
            openTask: task
        )
    }

    private static func noResultsResponse(
        language: MapsConversationLanguage,
        query: String,
        title: String
    ) -> MapsIntentRouterResponse? {
        let result = ConversationToolResult(
            id: "maps-no-results",
            title: title,
            summary: language.usesChineseCopy
                ? "“\(query)” 目前没有足够可靠的地图结果。"
                : "There are not enough reliable map results for “\(query)” right now.",
            state: .warning,
            metrics: [
                .init(key: language.usesChineseCopy ? "下一步 1" : "Next 1", value: language.usesChineseCopy ? "换区域" : "Try another area"),
                .init(key: language.usesChineseCopy ? "下一步 2" : "Next 2", value: language.usesChineseCopy ? "换关键词" : "Try another keyword"),
                .init(key: language.usesChineseCopy ? "下一步 3" : "Next 3", value: language.usesChineseCopy ? "手动输入地点" : "Enter a place manually")
            ],
            footer: language.usesChineseCopy
                ? "没有结果时不会直接跳图。"
                : "Maps will not open directly when the result set is empty.",
            actions: []
        )

        let text = language.usesChineseCopy
            ? "这次我先不打开 Maps。你可以换区域、换关键词，或者直接给我一个更具体的地点。"
            : "I’m not opening Maps for this one yet. Try another area, another keyword, or give me a more specific place."

        return MapsIntentRouterResponse(
            decision: .chatAnswer,
            message: .assistant(
                text: text,
                tags: ["Maps", language.usesChineseCopy ? "无结果" : "No results"],
                toolResults: [result]
            ),
            pendingTask: nil,
            openTask: nil
        )
    }

    private static func manualInputKind(for task: MapTask) -> MapManualInputKind {
        switch task.taskType {
        case .goToPlace:
            return .destination
        case .nearbySearch, .recommendation:
            return .anchor
        case .routeComparison:
            return .origin
        }
    }

    private static func permissionLabel(
        _ state: MapPermissionState,
        language: MapsConversationLanguage
    ) -> String {
        switch (state, language) {
        case (.authorizedWhenInUse, .chinese):
            return "前台可用"
        case (.authorizedWhenInUse, .english):
            return "While using"
        case (.notDetermined, .chinese):
            return "未决定"
        case (.notDetermined, .english):
            return "Not determined"
        case (.denied, .chinese):
            return "已拒绝"
        case (.denied, .english):
            return "Denied"
        case (.manualOnly, .chinese):
            return "手动地点"
        case (.manualOnly, .english):
            return "Manual place"
        case (.unknown, .chinese):
            return "未知"
        case (.unknown, .english):
            return "Unknown"
        }
    }

    private static func resolvedOrigin(
        from query: String?,
        language: MapsConversationLanguage,
        runtime: MapsRuntime
    ) async -> MapPlaceCandidate? {
        guard let query, query.isEmpty == false else {
            return nil
        }

        let results = await runtime.resolvePlaces(matching: query)
        guard let origin = results.first else {
            return nil
        }

        return MapPlaceCandidate(
            id: origin.id,
            title: origin.title,
            subtitle: origin.subtitle,
            coordinate: origin.coordinate,
            distanceText: origin.distanceText,
            reason: language.usesChineseCopy
                ? "作为路线起点。"
                : "Used as the route origin.",
            isCurrentLocation: origin.isCurrentLocation
        )
    }
}

private enum ParsedMapsIntent {
    case goTo(String, MapsConversationLanguage)
    case nearby(String, MapsConversationLanguage)
    case recommendation(String, MapsConversationLanguage)
    case route(destination: String, origin: String?, language: MapsConversationLanguage)

    static func parse(_ prompt: String) -> ParsedMapsIntent? {
        let language: MapsConversationLanguage = containsChinese(in: prompt) ? .chinese : .english
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        if let route = routeIntent(from: trimmed, normalized: normalized, language: language) {
            return route
        }

        if let query = nearbyQuery(from: trimmed, normalized: normalized) {
            return .nearby(query, language)
        }

        if let query = recommendationQuery(from: trimmed, normalized: normalized) {
            return .recommendation(query, language)
        }

        if let query = destinationQuery(from: trimmed, normalized: normalized) {
            return .goTo(query, language)
        }

        return nil
    }

    private static func routeIntent(
        from prompt: String,
        normalized: String,
        language: MapsConversationLanguage
    ) -> ParsedMapsIntent? {
        if language.usesChineseCopy {
            if prompt.contains("从"), prompt.contains("到"),
               let fromRange = prompt.range(of: "从"),
               let toRange = prompt.range(of: "到", range: fromRange.upperBound ..< prompt.endIndex) {
                let origin = String(prompt[fromRange.upperBound ..< toRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let destination = String(prompt[toRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if destination.isEmpty == false {
                    return .route(destination: destination, origin: origin.isEmpty ? nil : origin, language: language)
                }
            }

            let routeTokens = ["路线", "怎么去", "开车还是", "步行还是", "公交", "地铁", "规划路线"]
            if routeTokens.contains(where: prompt.contains),
               let destination = destinationQuery(from: prompt, normalized: normalized) ?? nearbyFreeformDestination(prompt) {
                return .route(destination: destination, origin: nil, language: language)
            }
        } else {
            if normalized.contains(" from "), normalized.contains(" to ") {
                let parts = normalized.components(separatedBy: " to ")
                if parts.count == 2 {
                    let left = parts[0]
                    let origin = left.components(separatedBy: " from ").last?.trimmingCharacters(in: .whitespaces)
                    let destination = parts[1].trimmingCharacters(in: .whitespaces)
                    if destination.isEmpty == false {
                        return .route(destination: destination, origin: origin, language: language)
                    }
                }
            }

            let routeTokens = ["route", "how do i get to", "how should i get to", "best way to get to", "drive or transit", "walk or drive"]
            if routeTokens.contains(where: normalized.contains),
               let destination = destinationQuery(from: prompt, normalized: normalized) ?? fallbackEnglishDestination(prompt) {
                return .route(destination: destination, origin: nil, language: language)
            }
        }

        return nil
    }

    private static func nearbyQuery(from prompt: String, normalized: String) -> String? {
        let chineseTokens = ["附近", "周围", "离我近"]
        if chineseTokens.contains(where: prompt.contains) {
            let cleaned = prompt
                .replacingOccurrences(of: "附近有什么", with: "")
                .replacingOccurrences(of: "附近有", with: "")
                .replacingOccurrences(of: "周围有", with: "")
                .replacingOccurrences(of: "离我近的", with: "")
                .replacingOccurrences(of: "吗", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? "地点" : cleaned
        }

        let englishTokens = ["near me", "nearby", "around me", "around here", "close to me"]
        guard englishTokens.contains(where: normalized.contains) else {
            return nil
        }

        let cleaned = normalized
            .replacingOccurrences(of: "find", with: "")
            .replacingOccurrences(of: "show me", with: "")
            .replacingOccurrences(of: "what", with: "")
            .replacingOccurrences(of: "is", with: "")
            .replacingOccurrences(of: "are", with: "")
            .replacingOccurrences(of: "near me", with: "")
            .replacingOccurrences(of: "nearby", with: "")
            .replacingOccurrences(of: "around me", with: "")
            .replacingOccurrences(of: "around here", with: "")
            .replacingOccurrences(of: "close to me", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "places" : cleaned
    }

    private static func recommendationQuery(from prompt: String, normalized: String) -> String? {
        let chineseTokens = ["适合", "找个", "帮我找", "哪家更方便", "推荐"]
        if chineseTokens.contains(where: prompt.contains) {
            return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let englishTokens = ["recommend", "good for", "best place for", "find a place for", "find somewhere"]
        if englishTokens.contains(where: normalized.contains) {
            return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    private static func destinationQuery(from prompt: String, normalized: String) -> String? {
        let chinesePrefixes = ["我想去", "我要去", "带我去", "带我到", "导航到", "去最近的"]
        for prefix in chinesePrefixes where prompt.hasPrefix(prefix) {
            let value = String(prompt.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        let englishPrefixes = ["i want to go to ", "i need to go to ", "take me to ", "navigate to ", "go to "]
        for prefix in englishPrefixes where normalized.hasPrefix(prefix) {
            let value = String(prompt.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        return nil
    }

    private static func nearbyFreeformDestination(_ prompt: String) -> String? {
        let tokens = ["怎么去", "路线", "规划路线", "开车还是", "步行还是", "公交"]
        for token in tokens where prompt.contains(token) {
            let cleaned = prompt.replacingOccurrences(of: token, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }

        return nil
    }

    private static func fallbackEnglishDestination(_ prompt: String) -> String? {
        let phrases = ["how do i get to ", "how should i get to ", "best way to get to "]
        let lowercased = prompt.lowercased()
        for phrase in phrases where lowercased.contains(phrase) {
            guard let range = lowercased.range(of: phrase) else { continue }
            let suffix = String(prompt[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return suffix.isEmpty ? nil : suffix
        }

        return nil
    }

    private static func containsChinese(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00 ... 0x9FFF).contains(Int(scalar.value))
        }
    }
}
