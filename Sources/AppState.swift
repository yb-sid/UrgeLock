import Foundation

enum ProtectionStatus: String, Codable {
    case off
    case on
    case cooldown  // password accepted, waiting to pause
    case paused
}

struct PersistedState: Codable {
    var isSetupComplete: Bool
    var protectionStatus: ProtectionStatus
    var cooldownEndsAt: Date?
    var pauseEndsAt: Date?
    var cooldownSeconds: TimeInterval
    var pauseDurationSeconds: TimeInterval
    var blockedAttemptHint: Int

    static var `default`: PersistedState {
        PersistedState(
            isSetupComplete: false,
            protectionStatus: .off,
            cooldownEndsAt: nil,
            pauseEndsAt: nil,
            cooldownSeconds: AppConfig.defaultCooldownSeconds,
            pauseDurationSeconds: AppConfig.defaultPauseDurationSeconds,
            blockedAttemptHint: 0
        )
    }
}

final class StateStore {
    static let shared = StateStore()
    private(set) var state: PersistedState
    private let queue = DispatchQueue(label: "app.urgelock.state")

    private init() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: AppConfig.stateURL),
           let decoded = try? dec.decode(PersistedState.self, from: data) {
            state = decoded
        } else {
            state = .default
        }
    }

    func update(_ mutate: (inout PersistedState) -> Void) {
        queue.sync {
            mutate(&state)
            save()
        }
    }

    private func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(state) {
            try? data.write(to: AppConfig.stateURL, options: .atomic)
        }
    }

    func reload() {
        queue.sync {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            if let data = try? Data(contentsOf: AppConfig.stateURL),
               let decoded = try? dec.decode(PersistedState.self, from: data) {
                state = decoded
            }
        }
    }
}
