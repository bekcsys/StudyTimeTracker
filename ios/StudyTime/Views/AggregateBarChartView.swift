import SwiftUI

/// Bar chart for year (12 months) or month (7 weekdays) aggregations.
struct AggregateBarChartView: View {
    let title: String
    let buckets: [ChartBucket]
    var topicBreakdown: [DayTopicStat] = []

    private let chartHeight: CGFloat = 180
    private let padLeft: CGFloat = 24
    private let padRight: CGFloat = 14
    private let padTop: CGFloat = 20
    private let padBottom: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Color.clear
                .frame(height: chartHeight)
                .overlay {
                    GeometryReader { geo in
                        BarChartCanvas(
                            buckets: buckets,
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
                    VStack(alignment: .leading, spacing: 3) {
                        Text(totalHoursLabel)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(6)
                }
                .clipped()

            ChartTopicLegend(topics: topicBreakdown)
        }
        .padding(16)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var totalHoursLabel: String {
        let totalSeconds = buckets.reduce(0) { $0 + $1.seconds }
        let hours = CGFloat(totalSeconds) / 3600
        let value = (hours * 10).rounded() / 10
        if value == 0 { return "Total 0h" }
        if value == value.rounded() {
            return "Total \(Int(value))h"
        }
        return String(format: "Total %.1fh", Double(value))
    }
}

private struct BarChartCanvas: View {
    let buckets: [ChartBucket]
    let width: CGFloat
    let height: CGFloat
    let padLeft: CGFloat
    let padRight: CGFloat
    let padTop: CGFloat
    let padBottom: CGFloat

    private var plotWidth: CGFloat { width - padLeft - padRight }
    private var plotHeight: CGFloat { height - padTop - padBottom }

    private var axisMax: CGFloat {
        let peakHours = buckets.map { CGFloat($0.seconds) / 3600 }.max() ?? 0
        // 10% headroom above the tallest bar
        return max(1, peakHours * 1.1)
    }

    /// Whole hours (labeled) and half-hours (unlabeled faint lines).
    private var yGridTicks: [(hours: CGFloat, labeled: Bool)] {
        let steps = Int(axisMax * 2)
        return (0...steps).map { step in
            let hours = CGFloat(step) * 0.5
            return (hours, step % 2 == 0)
        }
    }

    private var barWidth: CGFloat {
        guard !buckets.isEmpty else { return 8 }
        let gap: CGFloat = buckets.count > 10 ? 2 : 4
        let totalGaps = CGFloat(buckets.count - 1) * gap
        return max(4, (plotWidth - totalGaps) / CGFloat(buckets.count))
    }

    private var barGap: CGFloat {
        buckets.count > 10 ? 2 : 4
    }

    private var cumulativeMax: CGFloat {
        let totalHours = buckets.reduce(CGFloat(0)) { $0 + CGFloat($1.seconds) / 3600 }
        return max(1, totalHours * 1.1)
    }

    private var cumulativePoints: [CGPoint] {
        var running: CGFloat = 0
        return buckets.enumerated().map { index, bucket in
            running += CGFloat(bucket.seconds) / 3600
            let x = padLeft + CGFloat(index) * (barWidth + barGap) + barWidth / 2
            let y = padTop + plotHeight * (1 - running / cumulativeMax)
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            gridLayer
            barsLayer
            cumulativeLineLayer
            labelsLayer
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
                Text(formatAxisHours(tick.hours))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: padLeft - 2, alignment: .trailing)
                    .offset(x: 0, y: y - 6)
            }
        }
    }

    private var barsLayer: some View {
        ForEach(Array(buckets.enumerated()), id: \.offset) { index, bucket in
            let hours = CGFloat(bucket.seconds) / 3600
            let barHeight = plotHeight * (hours / axisMax)
            let x = padLeft + CGFloat(index) * (barWidth + barGap)
            let y = padTop + plotHeight - barHeight

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BrandColor.timer.opacity(0.95),
                            BrandColor.timer.opacity(0.55),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: barWidth, height: max(barHeight, bucket.seconds > 0 ? 2 : 0))
                .offset(x: x, y: y)
        }
    }

    private var cumulativeLineLayer: some View {
        smoothCumulativePath
            .stroke(
                Color.red,
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [3, 3])
            )
    }

    private var smoothCumulativePath: Path {
        var path = Path()
        let coords = cumulativePoints
        guard let first = coords.first else { return path }
        path.move(to: first)
        guard coords.count > 1 else { return path }

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
        return path
    }

    private var labelsLayer: some View {
        ForEach(Array(buckets.enumerated()), id: \.offset) { index, bucket in
            let x = padLeft + CGFloat(index) * (barWidth + barGap) + barWidth / 2
            Text(bucket.label)
                .font(.system(size: buckets.count > 14 ? 7 : 9))
                .foregroundStyle(.secondary)
                .frame(width: max(barWidth + 4, 14))
                .offset(x: x - max(barWidth + 4, 14) / 2, y: height - padBottom + 6)
        }
    }

    private func formatAxisHours(_ hours: CGFloat) -> String {
        if hours == 0 { return "0" }
        return "\(Int(hours.rounded()))h"
    }
}
