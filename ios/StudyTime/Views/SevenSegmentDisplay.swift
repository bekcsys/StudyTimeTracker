import SwiftUI

/// LCD-style 7-segment timer matching the web DSEG7 Classic look.
struct SevenSegmentDisplay: View {
    let hours: String
    let minutes: String
    let seconds: String
    let micros: String
    var activeColor: Color = .primary
    var inactiveColor: Color = Color.primary.opacity(0.12)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            HStack(spacing: 2) {
                SevenSegmentText(hours, digitHeight: 28, activeColor: activeColor, inactiveColor: inactiveColor)
                SevenSegmentColon(height: 28, color: activeColor.opacity(0.55))
                SevenSegmentText(minutes, digitHeight: 28, activeColor: activeColor.opacity(0.75), inactiveColor: inactiveColor)
            }

            HStack(spacing: 2) {
                SevenSegmentColon(height: 52, color: activeColor)
                SevenSegmentText(seconds, digitHeight: 52, activeColor: activeColor, inactiveColor: inactiveColor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(".")
                    .font(.system(size: 36, weight: .regular, design: .monospaced))
                    .foregroundStyle(activeColor.opacity(0.7))
                SevenSegmentText(micros, digitHeight: 40, activeColor: activeColor, inactiveColor: inactiveColor)
            }
        }
        .frame(maxWidth: .infinity)
        .lineLimit(1)
        .minimumScaleFactor(0.4)
    }
}

private struct SevenSegmentText: View {
    let text: String
    let digitHeight: CGFloat
    let activeColor: Color
    let inactiveColor: Color

    init(_ text: String, digitHeight: CGFloat, activeColor: Color, inactiveColor: Color) {
        self.text = text
        self.digitHeight = digitHeight
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }

    var body: some View {
        HStack(spacing: digitHeight * 0.12) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, char in
                SevenSegmentDigit(
                    character: char,
                    height: digitHeight,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor
                )
            }
        }
    }
}

private struct SevenSegmentColon: View {
    let height: CGFloat
    var color: Color = .primary

    var body: some View {
        VStack(spacing: height * 0.22) {
            Capsule()
                .fill(color)
                .frame(width: height * 0.12, height: height * 0.12)
            Capsule()
                .fill(color)
                .frame(width: height * 0.12, height: height * 0.12)
        }
        .frame(width: height * 0.28, height: height)
        .padding(.horizontal, 2)
    }
}

private struct SevenSegmentDigit: View {
    let character: Character
    let height: CGFloat
    var activeColor: Color = .primary
    var inactiveColor: Color = Color.primary.opacity(0.12)

    private var width: CGFloat { height * 0.58 }
    private var thickness: CGFloat { max(2.5, height * 0.12) }

    var body: some View {
        let on = Self.segments(for: character)
        Canvas { context, size in
            let t = thickness
            let inset = t * 0.35
            let midY = size.height / 2

            let paths: [Path] = [
                horizontal(atY: inset, width: size.width, thickness: t),
                vertical(atX: size.width - t, y0: inset, y1: midY, thickness: t),
                vertical(atX: size.width - t, y0: midY, y1: size.height - inset, thickness: t),
                horizontal(atY: size.height - inset - t, width: size.width, thickness: t),
                vertical(atX: 0, y0: midY, y1: size.height - inset, thickness: t),
                vertical(atX: 0, y0: inset, y1: midY, thickness: t),
                horizontal(atY: midY - t / 2, width: size.width, thickness: t),
            ]

            for (index, path) in paths.enumerated() {
                let active = on.contains(index)
                context.fill(
                    path,
                    with: .color(active ? activeColor : inactiveColor)
                )
            }
        }
        .frame(width: width, height: height)
        .accessibilityLabel(String(character))
    }

    private func horizontal(atY y: CGFloat, width: CGFloat, thickness t: CGFloat) -> Path {
        let tip = t * 0.45
        var path = Path()
        path.move(to: CGPoint(x: tip, y: y))
        path.addLine(to: CGPoint(x: width - tip, y: y))
        path.addLine(to: CGPoint(x: width, y: y + t / 2))
        path.addLine(to: CGPoint(x: width - tip, y: y + t))
        path.addLine(to: CGPoint(x: tip, y: y + t))
        path.addLine(to: CGPoint(x: 0, y: y + t / 2))
        path.closeSubpath()
        return path
    }

    private func vertical(atX x: CGFloat, y0: CGFloat, y1: CGFloat, thickness t: CGFloat) -> Path {
        let tip = t * 0.45
        let top = y0 + tip
        let bottom = y1 - tip
        var path = Path()
        path.move(to: CGPoint(x: x + t / 2, y: y0))
        path.addLine(to: CGPoint(x: x + t, y: top))
        path.addLine(to: CGPoint(x: x + t, y: bottom))
        path.addLine(to: CGPoint(x: x + t / 2, y: y1))
        path.addLine(to: CGPoint(x: x, y: bottom))
        path.addLine(to: CGPoint(x: x, y: top))
        path.closeSubpath()
        return path
    }

    /// Segment indices: a b c d e f g
    private static func segments(for character: Character) -> Set<Int> {
        switch character {
        case "0": return [0, 1, 2, 3, 4, 5]
        case "1": return [1, 2]
        case "2": return [0, 1, 3, 4, 6]
        case "3": return [0, 1, 2, 3, 6]
        case "4": return [1, 2, 5, 6]
        case "5": return [0, 2, 3, 5, 6]
        case "6": return [0, 2, 3, 4, 5, 6]
        case "7": return [0, 1, 2]
        case "8": return [0, 1, 2, 3, 4, 5, 6]
        case "9": return [0, 1, 2, 3, 5, 6]
        case "-": return [6]
        default: return []
        }
    }
}
