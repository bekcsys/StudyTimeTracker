import Foundation
import SwiftData

enum SessionStatus: String, Codable {
    case active
    case paused
    case completed
}

@Model
final class StudySession {
    @Attribute(.unique) var id: UUID
    var statusRaw: String
    var startedAt: Date
    var endedAt: Date?
    var lastStartedAt: Date?
    var accumulatedSeconds: Int
    var createdAt: Date
    var updatedAt: Date

    var topic: Topic?

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        topic: Topic,
        status: SessionStatus,
        startedAt: Date,
        endedAt: Date? = nil,
        lastStartedAt: Date? = nil,
        accumulatedSeconds: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.statusRaw = status.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.lastStartedAt = lastStartedAt
        self.accumulatedSeconds = accumulatedSeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.topic = topic
    }

    func effectiveSeconds(at now: Date) -> Int {
        var total = accumulatedSeconds
        if status == .active, let lastStartedAt {
            let extra = Int(now.timeIntervalSince(lastStartedAt))
            total += max(0, extra)
        }
        return max(0, total)
    }

    func endMoment(at now: Date) -> Date {
        switch status {
        case .completed:
            return endedAt ?? updatedAt
        case .active:
            return now
        case .paused:
            return updatedAt
        }
    }
}
