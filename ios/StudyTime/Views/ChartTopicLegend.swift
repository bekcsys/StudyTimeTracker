import SwiftUI

/// Topic totals legend shown below year / month / week charts.
struct ChartTopicLegend: View {
    let topics: [DayTopicStat]

    var body: some View {
        if topics.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Total time per Activity")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                ForEach(topics) { topic in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: topic.color))
                            .frame(width: 7, height: 7)

                        Text(topic.name)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 8)

                        Text(FormatDuration.hours(topic.seconds))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
}
