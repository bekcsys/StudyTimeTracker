import SwiftUI

struct WeekChartView: View {
    let week: [WeekDayStat]
    let dayDetails: [String: DayStats]

    private let chartHeight: CGFloat = 180
    private let padLeft: CGFloat = 24
    private let padRight: CGFloat = 14
    private let padTop: CGFloat = 28
    private let padBottom: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current week")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Color.clear
                .frame(height: chartHeight)
                .overlay {
                    GeometryReader { geo in
                        ChartCanvas(
                            week: week,
                            width: max(geo.size.width, 1),
                            height: chartHeight,
                            padLeft: padLeft,
                            padRight: padRight,
                            padTop: padTop,
                            padBottom: padBottom
                        )
                    }
                }
                .overlay(alignment: .topTrailing) {
                    chartBadge
                        .padding(6)
                }
                .clipped()

            ChartTopicLegend(topics: aggregatedTopics)
        }
        .padding(16)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var chartBadge: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(totalHoursLabel)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Capsule()
                    .fill(Color.red)
                    .frame(width: 10, height: 2)
                Text("Cumulative")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var aggregatedTopics: [DayTopicStat] {
        StatisticsService.topicBreakdown(
            dayKeys: week.map(\.date),
            days: dayDetails
        )
    }

    private var totalHoursLabel: String {
        let totalSeconds = week.reduce(0) { $0 + $1.seconds }
        let hours = CGFloat(totalSeconds) / 3600
        let value = (hours * 10).rounded() / 10
        if value == 0 { return "Total : 0.0h" }
        if value == value.rounded() {
            return "Total : \(Int(value)).0h"
        }
        return String(format: "Total : %.1fh", Double(value))
    }
}

private struct ChartCanvas: View {
    let week: [WeekDayStat]
    let width: CGFloat
    let height: CGFloat
    let padLeft: CGFloat
    let padRight: CGFloat
    let padTop: CGFloat
    let padBottom: CGFloat

    private var plotWidth: CGFloat { width - padLeft - padRight }
    private var plotHeight: CGFloat { height - padTop - padBottom }

    private var axisMax: CGFloat {
        let peakHours = week.map { CGFloat($0.seconds) / 3600 }.max() ?? 0
        // +1 hour above the busiest day
        return max(1, peakHours + 1)
    }

    private var points: [(x: CGFloat, y: CGFloat, day: WeekDayStat)] {
        week.enumerated().map { index, day in
            let hours = CGFloat(day.seconds) / 3600
            let x: CGFloat
            if week.count <= 1 {
                x = padLeft + plotWidth / 2
            } else {
                x = padLeft + (CGFloat(index) / CGFloat(week.count - 1)) * plotWidth
            }
            let y = padTop + plotHeight * (1 - hours / axisMax)
            return (x, y, day)
        }
    }

    /// Running total Mon→Sun, scaled to its own max so it fits as a faint secondary series.
    private var cumulativeMax: CGFloat {
        let totalHours = week.reduce(CGFloat(0)) { $0 + CGFloat($1.seconds) / 3600 }
        return max(1, totalHours * 1.1)
    }

    private var cumulativePoints: [CGPoint] {
        var running: CGFloat = 0
        return week.enumerated().map { index, day in
            running += CGFloat(day.seconds) / 3600
            let x: CGFloat
            if week.count <= 1 {
                x = padLeft + plotWidth / 2
            } else {
                x = padLeft + (CGFloat(index) / CGFloat(week.count - 1)) * plotWidth
            }
            let y = padTop + plotHeight * (1 - running / cumulativeMax)
            return CGPoint(x: x, y: y)
        }
    }

    /// Whole hours (labeled) and half-hours (unlabeled faint lines).
    private var yGridTicks: [(hours: CGFloat, labeled: Bool)] {
        let steps = Int(axisMax * 2)
        return (0...steps).map { step in
            let hours = CGFloat(step) * 0.5
            return (hours, step % 2 == 0)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            gridLayer
            cumulativeLineLayer
            areaLayer
            lineLayer
            markersLayer
            xAxisLabels
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
    }

    private var gridLayer: some View {
        ForEach(Array(yGridTicks.enumerated()), id: \.offset) { _, tick in
            let y = padTop + plotHeight * (1 - tick.hours / axisMax)
            let isBaseline = tick.hours == 0
            Path { path in
                path.move(to: CGPoint(x: padLeft, y: y))
                path.addLine(to: CGPoint(x: width - padRight, y: y))
            }
            .stroke(
                Color.primary.opacity(isBaseline ? 0.22 : 0.12),
                style: StrokeStyle(
                    lineWidth: 1,
                    dash: isBaseline ? [] : [4, 4]
                )
            )

            if tick.labeled {
                Text(Self.formatAxisHours(tick.hours))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: padLeft - 2, alignment: .trailing)
                    .offset(x: 0, y: y - 6)
            }
        }
    }

    private var cumulativeLineLayer: some View {
        cumulativePath
            .stroke(
                Color.red,
                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, dash: [3, 3])
            )
    }

    private var cumulativePath: Path {
        var path = Path()
        let coords = cumulativePoints
        guard let first = coords.first else { return path }
        path.move(to: first)
        for point in coords.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private var areaLayer: some View {
        smoothPath(closed: true)
            .fill(
                LinearGradient(
                    colors: [
                        BrandColor.timer.opacity(0.35),
                        BrandColor.timer.opacity(0.12),
                        BrandColor.timer.opacity(0.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private var lineLayer: some View {
        smoothPath(closed: false)
            .stroke(
                BrandColor.timer,
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
    }

    private var markersLayer: some View {
        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
            let hours = CGFloat(point.day.seconds) / 3600

            ZStack {
                // Hollow "hole" centered on the line
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 11, height: 11)
                Circle()
                    .strokeBorder(BrandColor.timer, lineWidth: 2.5)
                    .frame(width: 11, height: 11)

                // Tiny value above the hole, still anchored to the point
                Text(Self.formatPointHours(hours))
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .offset(y: -14)
            }
            .frame(width: 28, height: 28)
            .offset(x: point.x - 14, y: point.y - 14)
            .allowsHitTesting(false)
        }
    }

    /// Weekday labels stay fixed on the x-axis.
    private var xAxisLabels: some View {
        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
            Text(point.day.label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 36)
                .offset(x: point.x - 18, y: height - padBottom + 8)
        }
    }

    private func smoothPath(closed: Bool) -> Path {
        var path = Path()
        let coords = points.map { CGPoint(x: $0.x, y: $0.y) }
        guard let first = coords.first else { return path }
        path.move(to: first)
        guard coords.count > 1 else {
            if closed {
                path.addLine(to: CGPoint(x: first.x, y: padTop + plotHeight))
                path.closeSubpath()
            }
            return path
        }

        for index in 0..<(coords.count - 1) {
            let p0 = index > 0 ? coords[index - 1] : coords[index]
            let p1 = coords[index]
            let p2 = coords[index + 1]
            let p3 = index + 2 < coords.count ? coords[index + 2] : coords[index + 1]
            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 5,
                y: p1.y + (p2.y - p0.y) / 5
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 5,
                y: p2.y - (p3.y - p1.y) / 5
            )
            path.addCurve(to: p2, control1: control1, control2: control2)
        }

        if closed, let last = coords.last {
            path.addLine(to: CGPoint(x: last.x, y: padTop + plotHeight))
            path.addLine(to: CGPoint(x: first.x, y: padTop + plotHeight))
            path.closeSubpath()
        }
        return path
    }

    private static func formatPointHours(_ hours: CGFloat) -> String {
        let value = (hours * 10).rounded() / 10
        if value == 0 { return "0h" }
        if value == value.rounded() {
            return "\(Int(value))h"
        }
        return String(format: "%.1fh", Double(value))
    }

    private static func formatAxisHours(_ hours: CGFloat) -> String {
        if hours == 0 { return "0" }
        return "\(Int(hours.rounded()))h"
    }
}
