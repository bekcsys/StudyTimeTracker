import SwiftUI

/// Shared 7×53 (371-cell) heatmap used by Year view.
struct StudyHeatmapGrid: View {
    static let columns = 53
    static let rows = 7
    static let cellCount = columns * rows
    static let spacing: CGFloat = 2
    static let aspectRatio = CGFloat(columns) / CGFloat(rows)

    /// Flat fills in column-major order: index = column * rows + row.
    let cellFills: [Color]

    init(cellFills: [Color]) {
        precondition(cellFills.count == Self.cellCount)
        self.cellFills = cellFills
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let cell = Self.cellSize(in: geo.size)
                    HStack(spacing: Self.spacing) {
                        ForEach(0..<Self.columns, id: \.self) { column in
                            VStack(spacing: Self.spacing) {
                                ForEach(0..<Self.rows, id: \.self) { row in
                                    let index = column * Self.rows + row
                                    Rectangle()
                                        .fill(cellFills[index])
                                        .frame(width: cell, height: cell)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .allowsHitTesting(false)
    }

    static func cellSize(in size: CGSize) -> CGFloat {
        min(
            (size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
            (size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
        )
    }
}

enum StudyHeatmapData {
    static let studied = Color(hex: "#2a7a4b")
    static let pastIdle = Color.primary.opacity(0.08)
    static let futureIdle = Color.primary.opacity(0.22)

    /// Year mode: one cell per calendar day (column-major weeks).
    static func yearFills(
        year: Int,
        days: [String: DayStats],
        todayKey: String,
        qualifyingSeconds: Int
    ) -> [Color] {
        let jan1 = String(format: "%04d-01-01", year)
        let start = TimeUtils.weekStartKey(for: jan1)
        var fills: [Color] = []
        fills.reserveCapacity(StudyHeatmapGrid.cellCount)

        for column in 0..<StudyHeatmapGrid.columns {
            for row in 0..<StudyHeatmapGrid.rows {
                let key = TimeUtils.addDays(to: start, days: column * StudyHeatmapGrid.rows + row)
                if let parts = TimeUtils.parts(from: key), parts.year == year {
                    fills.append(dayFill(for: key, days: days, todayKey: todayKey, qualifyingSeconds: qualifyingSeconds))
                } else {
                    fills.append(.clear)
                }
            }
        }
        return fills
    }

    static func dayFill(
        for key: String,
        days: [String: DayStats],
        todayKey: String,
        qualifyingSeconds: Int
    ) -> Color {
        if (days[key]?.totalSeconds ?? 0) > qualifyingSeconds {
            return studied
        }
        if key > todayKey {
            return futureIdle
        }
        return pastIdle
    }
}

/// One cell per day of the month, sized to fill the shared year-grid footprint.
struct MonthDayHeatmap: View {
    let year: Int
    let month: Int
    let days: [String: DayStats]
    let todayKey: String
    let qualifyingSeconds: Int

    private let spacing: CGFloat = 2

    private var dayCount: Int {
        TimeUtils.daysInMonth(year: year, month: month)
    }

    private var dayKeys: [String] {
        (1...dayCount).map { day in
            String(format: "%04d-%02d-%02d", year, month, day)
        }
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(StudyHeatmapGrid.aspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let layout = optimalLayout(count: dayCount, in: geo.size)
                    let keys = dayKeys

                    VStack(spacing: spacing) {
                        ForEach(0..<layout.rows, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<layout.cols, id: \.self) { col in
                                    let index = row * layout.cols + col
                                    if index < keys.count {
                                        Rectangle()
                                            .fill(
                                                StudyHeatmapData.dayFill(
                                                    for: keys[index],
                                                    days: days,
                                                    todayKey: todayKey,
                                                    qualifyingSeconds: qualifyingSeconds
                                                )
                                            )
                                            .frame(width: layout.cell, height: layout.cell)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .allowsHitTesting(false)
    }

    private func optimalLayout(count: Int, in size: CGSize) -> (cols: Int, rows: Int, cell: CGFloat) {
        guard count > 0 else { return (1, 1, 0) }
        var bestCols = count
        var bestRows = 1
        var bestCell: CGFloat = 0

        for cols in 1...count {
            let rows = Int(ceil(Double(count) / Double(cols)))
            let cellW = (size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            let cell = min(cellW, cellH)
            if cell > bestCell {
                bestCell = cell
                bestCols = cols
                bestRows = rows
            }
        }

        return (bestCols, bestRows, bestCell)
    }
}

/// Compact year presence grid for the tracker page.
struct TrackerYearHeatmap: View {
    let year: Int
    let days: [String: DayStats]
    let todayKey: String

    /// Same threshold as Statistics calendar (1 minute for testing).
    private let qualifyingSeconds = 1 * 60

    private var activeDayCount: Int {
        let prefix = String(format: "%04d-", year)
        return days.reduce(0) { count, entry in
            let (key, day) = entry
            guard key.hasPrefix(prefix), day.totalSeconds > qualifyingSeconds else { return count }
            return count + 1
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(year)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(activeDayCount) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text("Just keep showing up")
                .font(.custom("Snell Roundhand", size: 22))
                .italic()
                .foregroundStyle(.primary.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)

            StudyHeatmapGrid(
                cellFills: StudyHeatmapData.yearFills(
                    year: year,
                    days: days,
                    todayKey: todayKey,
                    qualifyingSeconds: qualifyingSeconds
                )
            )
            .accessibilityLabel("Activity heatmap for \(year)")
        }
    }
}
