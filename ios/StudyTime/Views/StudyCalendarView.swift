import SwiftUI

enum CalendarViewMode: String, CaseIterable, Identifiable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

struct StudyCalendarView: View {
    @Binding var viewMode: CalendarViewMode
    let focusKey: String
    let days: [String: DayStats]
    let todayKey: String
    let trackingStartDate: String?
    let canGoPrev: Bool
    let onPrev: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void
    let onSelectDay: (String) -> Void
    let onSelectMonth: (Int, Int) -> Void

    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let qualifyingSeconds = 1 * 60

    private var focusParts: (year: Int, month: Int, day: Int) {
        TimeUtils.parts(from: focusKey) ?? (2026, 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("View", selection: $viewMode) {
                ForEach(CalendarViewMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text(headerTitle)
                    .font(headerFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                HStack(spacing: 4) {
                    Button(action: onPrev) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canGoPrev)

                    Button("Today", action: onToday)
                        .font(.subheadline)

                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.bordered)
            }

            gridSlot
        }
    }

    private var headerTitle: String {
        switch viewMode {
        case .year:
            return String(focusParts.year)
        case .month:
            return TimeUtils.monthLabel(year: focusParts.year, month: focusParts.month)
        case .week:
            return TimeUtils.weekLabel(containing: focusKey)
        }
    }

    private var headerFont: Font {
        switch viewMode {
        case .year:
            return .title3.weight(.semibold)
        case .month, .week:
            return .subheadline.weight(.semibold)
        }
    }

    @ViewBuilder
    private var gridSlot: some View {
        switch viewMode {
        case .year:
            StudyHeatmapGrid(
                cellFills: StudyHeatmapData.yearFills(
                    year: focusParts.year,
                    days: days,
                    todayKey: todayKey,
                    qualifyingSeconds: qualifyingSeconds
                )
            )
            .accessibilityLabel("Study heatmap for \(focusParts.year)")

        case .month:
            MonthDayHeatmap(
                year: focusParts.year,
                month: focusParts.month,
                days: days,
                todayKey: todayKey,
                qualifyingSeconds: qualifyingSeconds
            )
            .accessibilityLabel(
                "Study heatmap for \(TimeUtils.monthLabel(year: focusParts.year, month: focusParts.month))"
            )

        case .week:
            weekStripView
                .accessibilityLabel("Study week for \(TimeUtils.weekLabel(containing: focusKey))")
        }
    }

    /// Compact 7-day strip in the same footprint as Year/Month heatmaps.
    private var weekStripView: some View {
        let keys = TimeUtils.weekKeys(containing: focusKey)
        return Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(StudyHeatmapGrid.aspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let spacing: CGFloat = 4
                    let labelH: CGFloat = 12
                    let cellH = max(18, geo.size.height - labelH - 4)
                    let cellW = (geo.size.width - spacing * 6) / 7

                    VStack(spacing: 4) {
                        HStack(spacing: spacing) {
                            ForEach(Array(weekdays.enumerated()), id: \.offset) { _, label in
                                Text(label)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: cellW)
                            }
                        }

                        HStack(spacing: spacing) {
                            ForEach(keys, id: \.self) { key in
                                weekStripCell(
                                    key: key,
                                    width: cellW,
                                    height: cellH
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .allowsHitTesting(false)
    }

    private func weekStripCell(key: String, width: CGFloat, height: CGFloat) -> some View {
        let dayNum = TimeUtils.parts(from: key)?.day ?? 0
        let daySeconds = days[key]?.totalSeconds ?? 0
        let studied = daySeconds > qualifyingSeconds
        let isToday = key == todayKey
        let isFuture = key > todayKey
        let beforeTracking = trackingStartDate.map { key < $0 } ?? true
        let missed = isTrackable(key) && !studied

        return ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(weekCellFill(studied: studied, missed: missed, isFuture: isFuture, beforeTracking: beforeTracking))
                .overlay {
                    if isFuture {
                        DiagonalHatchPattern()
                            .stroke(Color(.separator).opacity(0.7), lineWidth: 1)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(
                            isToday ? Color.primary.opacity(0.45) : Color.clear,
                            lineWidth: isToday ? 1.5 : 0
                        )
                }

            Text("\(dayNum)")
                .font(.system(size: min(height * 0.35, 11), weight: isToday ? .bold : .semibold))
                .foregroundStyle(weekCellForeground(studied: studied, missed: missed, isFuture: isFuture, beforeTracking: beforeTracking))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if missed {
                Text("✗")
                    .font(.system(size: min(height * 0.28, 10), weight: .bold))
                    .foregroundStyle(Color(hex: "#c23b22"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(3)
            }
        }
        .frame(width: width, height: height)
    }

    private func weekCellFill(studied: Bool, missed: Bool, isFuture: Bool, beforeTracking: Bool) -> Color {
        if studied {
            return Color(hex: "#2a7a4b")
        }
        if isFuture {
            return Color(.systemBackground).opacity(0.55)
        }
        if beforeTracking {
            return Color.primary.opacity(0.08)
        }
        if missed {
            return Color(hex: "#c23b22").opacity(0.12)
        }
        return Color.primary.opacity(0.08)
    }

    private func weekCellForeground(studied: Bool, missed: Bool, isFuture: Bool, beforeTracking: Bool) -> Color {
        if studied {
            return .white
        }
        if isFuture || beforeTracking {
            return .secondary
        }
        return .primary
    }

    private func isTrackable(_ key: String) -> Bool {
        guard let trackingStartDate else { return false }
        return key >= trackingStartDate && key <= todayKey
    }
}

private struct DiagonalHatchPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 5
        let extra = rect.width + rect.height
        var offset: CGFloat = -extra
        while offset < extra {
            path.move(to: CGPoint(x: offset, y: 0))
            path.addLine(to: CGPoint(x: offset + rect.height, y: rect.height))
            offset += spacing
        }
        return path
    }
}
