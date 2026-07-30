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
    /// True when user last applied /etc/hosts extras (so we can re-apply after edits).
    var hostsModeEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case isSetupComplete, protectionStatus, cooldownEndsAt, pauseEndsAt
        case cooldownSeconds, pauseDurationSeconds, blockedAttemptHint, hostsModeEnabled
    }

    init(
        isSetupComplete: Bool,
        protectionStatus: ProtectionStatus,
        cooldownEndsAt: Date?,
        pauseEndsAt: Date?,
        cooldownSeconds: TimeInterval,
        pauseDurationSeconds: TimeInterval,
        blockedAttemptHint: Int,
        hostsModeEnabled: Bool
    ) {
        self.isSetupComplete = isSetupComplete
        self.protectionStatus = protectionStatus
        self.cooldownEndsAt = cooldownEndsAt
        self.pauseEndsAt = pauseEndsAt
        self.cooldownSeconds = cooldownSeconds
        self.pauseDurationSeconds = pauseDurationSeconds
        self.blockedAttemptHint = blockedAttemptHint
        self.hostsModeEnabled = hostsModeEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isSetupComplete = try c.decode(Bool.self, forKey: .isSetupComplete)
        protectionStatus = try c.decode(ProtectionStatus.self, forKey: .protectionStatus)
        cooldownEndsAt = try c.decodeIfPresent(Date.self, forKey: .cooldownEndsAt)
        pauseEndsAt = try c.decodeIfPresent(Date.self, forKey: .pauseEndsAt)
        cooldownSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .cooldownSeconds)
            ?? AppConfig.defaultCooldownSeconds
        pauseDurationSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .pauseDurationSeconds)
            ?? AppConfig.defaultPauseDurationSeconds
        blockedAttemptHint = try c.decodeIfPresent(Int.self, forKey: .blockedAttemptHint) ?? 0
        hostsModeEnabled = try c.decodeIfPresent(Bool.self, forKey: .hostsModeEnabled) ?? false
    }

    static var `default`: PersistedState {
        PersistedState(
            isSetupComplete: false,
            protectionStatus: .off,
            cooldownEndsAt: nil,
            pauseEndsAt: nil,
            cooldownSeconds: AppConfig.defaultCooldownSeconds,
            pauseDurationSeconds: AppConfig.defaultPauseDurationSeconds,
            blockedAttemptHint: 0,
            hostsModeEnabled: false
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
