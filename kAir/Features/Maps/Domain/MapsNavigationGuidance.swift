//
//  MapsNavigationGuidance.swift
//  kAir
//
//  Heuristics for maneuver and lane guidance derived from MapKit route steps.
//

import Foundation

enum MapManeuverSemantic: Hashable {
    case start
    case straight
    case keepLeft
    case keepRight
    case turnLeft
    case turnRight
    case slightLeft
    case slightRight
    case uTurn
    case offRampLeft
    case offRampRight
    case arrive
    case roundabout
}

enum MapLaneStatus: Hashable {
    case notGood
    case good
    case preferred
}

enum MapLaneDirection: Hashable {
    case left
    case slightLeft
    case straight
    case slightRight
    case right
    case uTurn
}

struct MapLaneDescriptor: Identifiable, Hashable {
    let id: String
    let directions: [MapLaneDirection]
    let highlightedDirection: MapLaneDirection?
    let status: MapLaneStatus

    init(
        id: String = UUID().uuidString,
        directions: [MapLaneDirection],
        highlightedDirection: MapLaneDirection? = nil,
        status: MapLaneStatus
    ) {
        self.id = id
        self.directions = directions
        self.highlightedDirection = highlightedDirection
        self.status = status
    }
}

struct MapLaneGuidanceModel: Hashable {
    let instructionVariants: [String]
    let lanes: [MapLaneDescriptor]
}

enum MapNavigationHeuristics {
    static func maneuver(
        for step: MapRouteStep,
        language: MapsConversationLanguage
    ) -> MapManeuverSemantic {
        let text = step.instruction.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard text.isEmpty == false else {
            return .straight
        }

        if containsAny(text, ["arrive", "destination", "到达", "目的地", "终点"]) {
            return .arrive
        }
        if containsAny(text, ["u-turn", "掉头", "调头"]) {
            return .uTurn
        }
        if containsAny(text, ["roundabout", "环岛"]) {
            return .roundabout
        }
        if containsAny(text, ["keep left", "靠左", "向左前方", "左侧保持"]) {
            return .keepLeft
        }
        if containsAny(text, ["keep right", "靠右", "向右前方", "右侧保持"]) {
            return .keepRight
        }
        if containsAny(text, ["slight left", "稍向左", "左前"]) {
            return .slightLeft
        }
        if containsAny(text, ["slight right", "稍向右", "右前"]) {
            return .slightRight
        }
        if containsAny(text, ["ramp", "exit", "匝道", "出口"]) {
            if containsAny(text, ["left", "左"]) {
                return .offRampLeft
            }
            if containsAny(text, ["right", "右"]) {
                return .offRampRight
            }
        }
        if containsAny(text, ["turn left", "左转"]) {
            return .turnLeft
        }
        if containsAny(text, ["turn right", "右转"]) {
            return .turnRight
        }
        if containsAny(text, ["head", "continue", "直行", "继续前往"]) {
            return .straight
        }

        return .straight
    }

    static func laneGuidance(
        for step: MapRouteStep,
        language: MapsConversationLanguage
    ) -> MapLaneGuidanceModel? {
        let semantic = maneuver(for: step, language: language)
        let lanes = lanePattern(for: semantic)
        guard lanes.isEmpty == false else {
            return nil
        }

        let instruction = step.instruction.isEmpty
            ? defaultInstruction(for: semantic, language: language)
            : step.instruction

        return MapLaneGuidanceModel(
            instructionVariants: [instruction, shortInstruction(for: semantic, language: language)],
            lanes: lanes
        )
    }

    private static func lanePattern(for semantic: MapManeuverSemantic) -> [MapLaneDescriptor] {
        switch semantic {
        case .start, .arrive:
            return []
        case .straight:
            return [
                MapLaneDescriptor(directions: [.left, .straight], highlightedDirection: .straight, status: .good),
                MapLaneDescriptor(directions: [.straight], highlightedDirection: .straight, status: .preferred),
                MapLaneDescriptor(directions: [.straight, .right], highlightedDirection: .straight, status: .good)
            ]
        case .keepLeft:
            return [
                MapLaneDescriptor(directions: [.slightLeft, .left], highlightedDirection: .slightLeft, status: .preferred),
                MapLaneDescriptor(directions: [.straight], highlightedDirection: .straight, status: .good),
                MapLaneDescriptor(directions: [.right], status: .notGood)
            ]
        case .keepRight:
            return [
                MapLaneDescriptor(directions: [.left], status: .notGood),
                MapLaneDescriptor(directions: [.straight], highlightedDirection: .straight, status: .good),
                MapLaneDescriptor(directions: [.slightRight, .right], highlightedDirection: .slightRight, status: .preferred)
            ]
        case .turnLeft:
            return [
                MapLaneDescriptor(directions: [.left], highlightedDirection: .left, status: .preferred),
                MapLaneDescriptor(directions: [.left, .straight], highlightedDirection: .left, status: .good),
                MapLaneDescriptor(directions: [.straight], status: .notGood)
            ]
        case .turnRight:
            return [
                MapLaneDescriptor(directions: [.straight], status: .notGood),
                MapLaneDescriptor(directions: [.straight, .right], highlightedDirection: .right, status: .good),
                MapLaneDescriptor(directions: [.right], highlightedDirection: .right, status: .preferred)
            ]
        case .slightLeft:
            return [
                MapLaneDescriptor(directions: [.slightLeft, .straight], highlightedDirection: .slightLeft, status: .preferred),
                MapLaneDescriptor(directions: [.straight], highlightedDirection: .straight, status: .good),
                MapLaneDescriptor(directions: [.right], status: .notGood)
            ]
        case .slightRight:
            return [
                MapLaneDescriptor(directions: [.left], status: .notGood),
                MapLaneDescriptor(directions: [.straight], highlightedDirection: .straight, status: .good),
                MapLaneDescriptor(directions: [.straight, .slightRight], highlightedDirection: .slightRight, status: .preferred)
            ]
        case .uTurn:
            return [
                MapLaneDescriptor(directions: [.uTurn], highlightedDirection: .uTurn, status: .preferred),
                MapLaneDescriptor(directions: [.left], status: .notGood)
            ]
        case .offRampLeft:
            return [
                MapLaneDescriptor(directions: [.left, .slightLeft], highlightedDirection: .slightLeft, status: .preferred),
                MapLaneDescriptor(directions: [.straight], highlightedDirection: .straight, status: .good),
                MapLaneDescriptor(directions: [.right], status: .notGood)
            ]
        case .offRampRight:
            return [
                MapLaneDescriptor(directions: [.left], status: .notGood),
                MapLaneDescriptor(directions: [.straight], highlightedDirection: .straight, status: .good),
                MapLaneDescriptor(directions: [.slightRight, .right], highlightedDirection: .slightRight, status: .preferred)
            ]
        case .roundabout:
            return [
                MapLaneDescriptor(directions: [.left, .straight], highlightedDirection: .straight, status: .good),
                MapLaneDescriptor(directions: [.straight], highlightedDirection: .straight, status: .preferred),
                MapLaneDescriptor(directions: [.straight, .right], highlightedDirection: .straight, status: .good)
            ]
        }
    }

    private static func defaultInstruction(
        for semantic: MapManeuverSemantic,
        language: MapsConversationLanguage
    ) -> String {
        switch (semantic, language.usesChineseCopy) {
        case (.start, true):
            return "开始沿当前路线前进"
        case (.start, false):
            return "Start on the current route"
        case (.straight, true):
            return "继续直行"
        case (.straight, false):
            return "Continue straight"
        case (.keepLeft, true):
            return "保持靠左"
        case (.keepLeft, false):
            return "Keep left"
        case (.keepRight, true):
            return "保持靠右"
        case (.keepRight, false):
            return "Keep right"
        case (.turnLeft, true):
            return "准备左转"
        case (.turnLeft, false):
            return "Prepare to turn left"
        case (.turnRight, true):
            return "准备右转"
        case (.turnRight, false):
            return "Prepare to turn right"
        case (.slightLeft, true):
            return "稍向左前方行驶"
        case (.slightLeft, false):
            return "Bear slightly left"
        case (.slightRight, true):
            return "稍向右前方行驶"
        case (.slightRight, false):
            return "Bear slightly right"
        case (.uTurn, true):
            return "准备掉头"
        case (.uTurn, false):
            return "Prepare for a U-turn"
        case (.offRampLeft, true):
            return "从左侧匝道驶出"
        case (.offRampLeft, false):
            return "Take the left ramp"
        case (.offRampRight, true):
            return "从右侧匝道驶出"
        case (.offRampRight, false):
            return "Take the right ramp"
        case (.arrive, true):
            return "即将到达目的地"
        case (.arrive, false):
            return "Destination is ahead"
        case (.roundabout, true):
            return "进入环岛并按出口驶离"
        case (.roundabout, false):
            return "Enter the roundabout and take the exit"
        }
    }

    private static func shortInstruction(
        for semantic: MapManeuverSemantic,
        language: MapsConversationLanguage
    ) -> String {
        switch (semantic, language.usesChineseCopy) {
        case (.start, true):
            return "出发"
        case (.start, false):
            return "Start"
        case (.straight, true):
            return "直行"
        case (.straight, false):
            return "Straight"
        case (.keepLeft, true):
            return "靠左"
        case (.keepLeft, false):
            return "Keep left"
        case (.keepRight, true):
            return "靠右"
        case (.keepRight, false):
            return "Keep right"
        case (.turnLeft, true):
            return "左转"
        case (.turnLeft, false):
            return "Left"
        case (.turnRight, true):
            return "右转"
        case (.turnRight, false):
            return "Right"
        case (.slightLeft, true):
            return "左前"
        case (.slightLeft, false):
            return "Slight left"
        case (.slightRight, true):
            return "右前"
        case (.slightRight, false):
            return "Slight right"
        case (.uTurn, true):
            return "掉头"
        case (.uTurn, false):
            return "U-turn"
        case (.offRampLeft, true):
            return "左匝道"
        case (.offRampLeft, false):
            return "Left ramp"
        case (.offRampRight, true):
            return "右匝道"
        case (.offRampRight, false):
            return "Right ramp"
        case (.arrive, true):
            return "到达"
        case (.arrive, false):
            return "Arrive"
        case (.roundabout, true):
            return "环岛"
        case (.roundabout, false):
            return "Roundabout"
        }
    }

    private static func containsAny(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains { text.contains($0) }
    }
}

extension MapNavigationSession {
    var currentStep: MapRouteStep? {
        guard steps.indices.contains(currentStepIndex) else {
            return nil
        }
        return steps[currentStepIndex]
    }
}
