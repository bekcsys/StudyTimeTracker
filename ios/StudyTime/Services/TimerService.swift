import Foundation
import SwiftData

struct TimerState: Equatable {
    var status: String
    var sessionId: UUID?
    var elapsedSeconds: Int
    var startedAt: Date?
    var topicId: UUID?
    var topicName: String?

    static let idle = TimerState(
        status: "idle",
        sessionId: nil,
        elapsedSeconds: 0,
        startedAt: nil,
        topicId: nil,
        topicName: nil
    )
}

enum TimerError: LocalizedError {
    case alreadyRunning
    case topicNotFound
    case noActiveTimer
    case noPausedTimer
    case noTimerToStop
    case invalidTopicName
    case duplicateTopicName

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "A timer is already active or paused"
        case .topicNotFound:
            return "Topic not found"
        case .noActiveTimer:
            return "No active timer to pause"
        case .noPausedTimer:
            return "No paused timer to resume"
        case .noTimerToStop:
            return "No timer to stop"
        case .invalidTopicName:
            return "Topic names may include letters, numbers, spaces, + and -"
        case .duplicateTopicName:
            return "A topic with that name already exists"
        }
    }
}

@MainActor
final class TimerService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getOpenSession() throws -> StudySession? {
        let descriptor = FetchDescriptor<StudySession>(
            predicate: #Predicate { $0.statusRaw != "completed" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    func timerState(now: Date = .now) throws -> TimerState {
        guard let session = try getOpenSession() else {
            return .idle
        }
        return TimerState(
            status: session.status == .active ? "active" : "paused",
            sessionId: session.id,
            elapsedSeconds: session.effectiveSeconds(at: now),
            startedAt: session.startedAt,
            topicId: session.topic?.id,
            topicName: session.topic?.name
        )
    }

    func start(topicId: UUID, now: Date = .now) throws -> TimerState {
        if try getOpenSession() != nil {
            throw TimerError.alreadyRunning
        }

        let topicDescriptor = FetchDescriptor<Topic>(
            predicate: #Predicate { $0.id == topicId }
        )
        guard let topic = try modelContext.fetch(topicDescriptor).first else {
            throw TimerError.topicNotFound
        }

        let session = StudySession(
            topic: topic,
            status: .active,
            startedAt: now,
            lastStartedAt: now,
            accumulatedSeconds: 0,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(session)
        try modelContext.save()
        return try timerState(now: now)
    }

    func pause(now: Date = .now) throws -> TimerState {
        guard let session = try getOpenSession(),
              session.status == .active,
              let lastStartedAt = session.lastStartedAt
        else {
            throw TimerError.noActiveTimer
        }

        let extra = max(0, Int(now.timeIntervalSince(lastStartedAt)))
        session.status = .paused
        session.accumulatedSeconds += extra
        session.lastStartedAt = nil
        session.updatedAt = now
        try modelContext.save()
        return try timerState(now: now)
    }

    func resume(now: Date = .now) throws -> TimerState {
        guard let session = try getOpenSession(),
              session.status == .paused
        else {
            throw TimerError.noPausedTimer
        }

        session.status = .active
        session.lastStartedAt = now
        session.updatedAt = now
        try modelContext.save()
        return try timerState(now: now)
    }

    func stop(now: Date = .now) throws -> TimerState {
        guard let session = try getOpenSession() else {
            throw TimerError.noTimerToStop
        }

        var accumulated = session.accumulatedSeconds
        if session.status == .active, let lastStartedAt = session.lastStartedAt {
            let extra = max(0, Int(now.timeIntervalSince(lastStartedAt)))
            accumulated += extra
        }

        session.status = .completed
        session.accumulatedSeconds = accumulated
        session.endedAt = now
        session.lastStartedAt = nil
        session.updatedAt = now
        try modelContext.save()
        return .idle
    }

    func fetchTopics() throws -> [Topic] {
        let descriptor = FetchDescriptor<Topic>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    @discardableResult
    func createTopic(name: String) throws -> Topic {
        let cleaned = Self.normalizeTopicName(name)
        guard Self.isValidTopicName(cleaned) else {
            throw TimerError.invalidTopicName
        }

        let existing = try fetchTopics()
        if let match = existing.first(where: { $0.name == cleaned }) {
            return match
        }

        let used = Set(existing.map(\.color))
        let color = TopicPalette.nextColor(used: used, topicCount: existing.count)
        let topic = Topic(name: cleaned, color: color)
        modelContext.insert(topic)
        try modelContext.save()
        return topic
    }

    func renameTopic(id: UUID, name: String) throws -> Topic {
        let cleaned = Self.normalizeTopicName(name)
        guard Self.isValidTopicName(cleaned) else {
            throw TimerError.invalidTopicName
        }

        let descriptor = FetchDescriptor<Topic>(
            predicate: #Predicate { $0.id == id }
        )
        guard let topic = try modelContext.fetch(descriptor).first else {
            throw TimerError.topicNotFound
        }

        let others = try fetchTopics().filter { $0.id != id }
        if others.contains(where: { $0.name == cleaned }) {
            throw TimerError.duplicateTopicName
        }

        topic.name = cleaned
        try modelContext.save()
        return topic
    }

    static func normalizeTopicName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func isValidTopicName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 120 else { return false }
        let pattern = #"^[A-Za-z0-9+\- ]+$"#
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}
