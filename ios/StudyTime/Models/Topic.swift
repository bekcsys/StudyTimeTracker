import Foundation
import SwiftData

@Model
final class Topic {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var color: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \StudySession.topic)
    var sessions: [StudySession] = []

    init(
        id: UUID = UUID(),
        name: String,
        color: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }
}

enum TopicPalette {
    static let colors: [String] = [
        "#c23b22",
        "#2a7a4b",
        "#2f5d9f",
        "#b8860b",
        "#7a3e9d",
        "#c45c26",
        "#0f7a7a",
        "#8b4513",
    ]

    static func nextColor(used: Set<String>, topicCount: Int) -> String {
        for color in colors where !used.contains(color) {
            return color
        }
        return colors[topicCount % colors.count]
    }
}
