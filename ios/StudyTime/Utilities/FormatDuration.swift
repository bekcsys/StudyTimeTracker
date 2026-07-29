import Foundation

enum FormatDuration {
    static func hours(_ totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(hours)h"
    }

    static func minutes(_ totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        let totalMinutes = seconds / 60
        if totalMinutes > 59 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        }
        return "\(totalMinutes)m"
    }

    static func timerParts(totalMicroseconds: Int64) -> (
        hours: String,
        minutes: String,
        seconds: String,
        micros: String
    ) {
        let total = max(Int64(0), totalMicroseconds)
        let hours = total / 3_600_000_000
        let minutes = (total % 3_600_000_000) / 60_000_000
        let secs = (total % 60_000_000) / 1_000_000
        let micros = (total % 1_000_000) / 10_000
        return (
            String(format: "%02d", hours),
            String(format: "%02d", minutes),
            String(format: "%02d", secs),
            String(format: "%02d", micros)
        )
    }
}
