//
//  ChatSessionPersistence.swift
//  kAir
//
//  Minimal local persistence for the active chat thread.
//

import Foundation

struct ChatSessionPersistence {
    private let defaults: UserDefaults
    private let storageKey = "com.kair.chat.active-session"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ChatSession? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(ChatSession.self, from: data)
        } catch {
            defaults.removeObject(forKey: storageKey)
            return nil
        }
    }

    func save(_ session: ChatSession) {
        do {
            let data = try JSONEncoder().encode(session)
            defaults.set(data, forKey: storageKey)
        } catch {
            defaults.removeObject(forKey: storageKey)
        }
    }

    func remove() {
        defaults.removeObject(forKey: storageKey)
    }
}
